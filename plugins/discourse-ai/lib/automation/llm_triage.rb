# frozen_string_literal: true
#
module DiscourseAi
  module Automation
    module LlmTriage
      def self.handle(
        post:,
        model:,
        search_for_text:,
        system_prompt:,
        category_id: nil,
        tags: nil,
        canned_reply: nil,
        canned_reply_user: nil,
        hide_topic: nil,
        flag_post: nil,
        flag_type: nil,
        automation: nil,
        max_post_tokens: nil,
        stop_sequences: nil,
        temperature: nil,
        whisper: nil,
        reply_persona_id: nil,
        max_output_tokens: nil,
        action: nil
      )
        if category_id.blank? && tags.blank? && canned_reply.blank? && hide_topic.blank? &&
             flag_post.blank? && reply_persona_id.blank?
          raise ArgumentError, "llm_triage: no action specified!"
        end

        if action == :edit && category_id.blank? && tags.blank? && flag_post.blank? &&
             hide_topic.blank?
          return
        end

        llm = DiscourseAi::Completions::Llm.proxy(model)

        s_prompt = system_prompt.to_s.sub("%%POST%%", "") # Backwards-compat. We no longer sub this.
        prompt = DiscourseAi::Completions::Prompt.new(s_prompt)

        content = "title: #{post.topic.title}\n#{post.raw}"

        content =
          llm.tokenizer.truncate(
            content,
            max_post_tokens,
            strict: SiteSetting.ai_strict_token_counting,
          ) if max_post_tokens.present?

        if post.upload_ids.present?
          content = [content]
          content.concat(post.upload_ids.map { |upload_id| { upload_id: upload_id } })
        end

        prompt.push(type: :user, content: content)

        result = nil

        result =
          llm.generate(
            prompt,
            max_tokens: max_output_tokens,
            temperature: temperature,
            user: Discourse.system_user,
            stop_sequences: stop_sequences,
            feature_name: "llm_triage",
            feature_context: {
              automation_id: automation&.id,
              automation_name: automation&.name,
            },
          )&.strip

        if result.present? && result.downcase.include?(search_for_text.downcase)
          user = User.find_by_username(canned_reply_user) if canned_reply_user.present?
          original_user = user
          user = user || Discourse.system_user
          if reply_persona_id.present? && action != :edit
            begin
              DiscourseAi::AiBot::Playground.reply_to_post(
                post: post,
                persona_id: reply_persona_id,
                whisper: whisper,
                user: original_user,
              )
            rescue StandardError => e
              Discourse.warn_exception(
                e,
                message: "Error responding to: #{post&.url} in LlmTriage.handle",
              )
              raise e if Rails.env.test?
            end
          elsif canned_reply.present? && action != :edit
            post_type = whisper ? Post.types[:whisper] : Post.types[:regular]
            PostCreator.create!(
              user,
              topic_id: post.topic_id,
              raw: canned_reply,
              reply_to_post_number: post.post_number,
              skip_validations: true,
              post_type: post_type,
            )
          end

          changes = {}
          changes[:category_id] = category_id if category_id.present?
          if SiteSetting.tagging_enabled? && tags.present?
            changes[:tags] = post.topic.tags.map(&:name).concat(tags)
          end

          if changes.present?
            first_post = post.topic.posts.where(post_number: 1).first
            changes[:bypass_bump] = true
            changes[:skip_validations] = true
            first_post.revise(Discourse.system_user, changes)
          end

          post.topic.update!(visible: false) if hide_topic

          if flag_post
            score_reason =
              I18n
                .t("discourse_automation.scriptables.llm_triage.flagged_post")
                .sub("%%LLM_RESPONSE%%", result)
                .sub("%%AUTOMATION_ID%%", automation&.id.to_s)
                .sub("%%AUTOMATION_NAME%%", automation&.name.to_s)

            if flag_type == :spam || flag_type == :spam_silence
              result =
                PostActionCreator.new(
                  Discourse.system_user,
                  post,
                  PostActionType.types[:spam],
                  message: score_reason,
                  queue_for_review: true,
                ).perform

              if flag_type == :spam_silence
                if result.success?
                  SpamRule::AutoSilence.new(post.user, post).silence_user
                else
                  Rails.logger.warn(
                    "llm_triage: unable to flag post as spam, post action failed for #{post.id} with error: '#{result.errors.full_messages.join(",").truncate(3000)}'",
                  )
                end
              end
            else
              reviewable =
                ReviewablePost.needs_review!(target: post, created_by: Discourse.system_user)

              reviewable.add_score(
                Discourse.system_user,
                ReviewableScore.types[:needs_approval],
                reason: score_reason,
                force_review: true,
              )

              # We cannot do this through the PostActionCreator because hiding a post is reserved for auto action flags.
              # Those flags are off_topic, inappropiate, and spam. We want a more generic type for triage, so none of those
              # fit here.
              post.hide!(PostActionType.types[:notify_moderators]) if flag_type == :review_hide
            end
          end
        end
      end
    end
  end
end
