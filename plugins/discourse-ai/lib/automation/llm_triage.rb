# frozen_string_literal: true
#
module DiscourseAi
  module Automation
    module LlmTriage
      def self.handle(
        post:,
        triage_persona_id:,
        search_for_text:,
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
        whisper: nil,
        reply_persona_id: nil,
        max_output_tokens: nil,
        action: nil,
        notify_author_pm: nil,
        notify_author_pm_user: nil,
        notify_author_pm_message: nil
      )
        if category_id.blank? && tags.blank? && canned_reply.blank? && hide_topic.blank? &&
             flag_post.blank? && reply_persona_id.blank?
          raise ArgumentError, "llm_triage: no action specified!"
        end

        if action == :edit && category_id.blank? && tags.blank? && flag_post.blank? &&
             hide_topic.blank?
          return
        end

        triage_persona = AiPersona.find(triage_persona_id)
        model_id = triage_persona.default_llm_id || SiteSetting.ai_default_llm_model
        return if model_id.blank?
        model = LlmModel.find(model_id)

        bot =
          DiscourseAi::Personas::Bot.as(
            Discourse.system_user,
            persona: triage_persona.class_instance.new,
            model: model,
          )

        input = "title: #{post.topic.title}\n#{post.raw}"

        input =
          model.tokenizer_class.truncate(
            input,
            max_post_tokens,
            strict: SiteSetting.ai_strict_token_counting,
          ) if max_post_tokens.present?

        if post.upload_ids.present?
          input = [input]
          input.concat(post.upload_ids.map { |upload_id| { upload_id: upload_id } })
        end

        bot_ctx =
          DiscourseAi::Personas::BotContext.new(
            user: Discourse.system_user,
            skip_tool_details: true,
            feature_name: "llm_triage",
            messages: [{ type: :user, content: input }],
          )

        result = nil

        llm_args = {
          max_tokens: max_output_tokens,
          stop_sequences: stop_sequences,
          feature_context: {
            automation_id: automation&.id,
            automation_name: automation&.name,
          },
        }

        result = +""
        bot.reply(bot_ctx, llm_args: llm_args) do |partial, _, type|
          result << partial if type.blank?
        end

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
              if flag_type == :review_hide
                post.hide!(PostActionType.types[:notify_moderators])
              elsif flag_type == :review_delete
                # Soft-delete the post so it is hidden from users until a moderator handles it in review.
                PostDestroyer.new(Discourse.system_user, post, context: "llm_triage").destroy
              end

              if notify_author_pm && action != :edit
                begin
                  pm_sender =
                    if notify_author_pm_user.present?
                      User.find_by_username(notify_author_pm_user)
                    else
                      nil
                    end
                  pm_sender ||= Discourse.system_user

                  subject =
                    I18n.t("discourse_automation.scriptables.llm_triage.notify_author_pm.subject")

                  default_body =
                    I18n.t(
                      "discourse_automation.scriptables.llm_triage.notify_author_pm.body",
                      username: post.user.username,
                      topic_title: post.topic.title,
                      post_url: post.url,
                    )

                  body = notify_author_pm_message.presence || default_body

                  PostCreator.create!(
                    pm_sender,
                    title: subject,
                    raw: body,
                    archetype: Archetype.private_message,
                    target_usernames: post.user.username,
                    skip_validations: true,
                  )
                rescue StandardError => e
                  Discourse.warn_exception(
                    e,
                    message:
                      "Error sending PM notification for triage on: #{post&.url} in LlmTriage.handle",
                  )
                  raise e if Rails.env.test?
                end
              end
            end
          end
        end
      end
    end
  end
end
