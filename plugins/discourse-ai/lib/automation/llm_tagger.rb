# frozen_string_literal: true

module DiscourseAi
  module Automation
    module LlmTagger
      def self.handle(
        post:,
        tagger_persona_id:,
        tag_mode: "manual",
        available_tags: [],
        confidence_threshold:,
        max_tags:,
        max_post_tokens:,
        allow_restricted_tags: false,
        max_posts_for_context: 5,
        automation: nil
      )
        # Skip if manual mode but no tags provided
        return if tag_mode == "manual" && available_tags.empty?

        tagger_persona = AiPersona.find(tagger_persona_id)
        model_id = tagger_persona.default_llm_id || SiteSetting.ai_default_llm_model
        return if model_id.blank?
        model = LlmModel.find(model_id)

        topic_posts = post.topic.posts.order(:post_number).limit(max_posts_for_context)
        posts_content = topic_posts.map { |p| "Post #{p.post_number}: #{p.raw}" }.join("\n\n")

        if tag_mode == "manual"
          # Manual mode: provide specific tag list in prompt
          available_tags_text = "Available tags: #{available_tags.join(", ")}\n\n"
          input =
            "#{available_tags_text}Topic to analyze:\ntitle: #{post.topic.title}\n\n#{posts_content}"
        else
          # Discover mode: instruct AI to use list_tags tool
          input =
            "Topic to analyze:\ntitle: #{post.topic.title}\n\n#{posts_content}\n\nUse the list_tags tool to see available tags, then suggest appropriate ones."
        end

        if max_post_tokens.present?
          input =
            model.tokenizer_class.truncate(
              input,
              max_post_tokens,
              strict: SiteSetting.ai_strict_token_counting,
            )
        end

        all_upload_ids = topic_posts.flat_map(&:upload_ids).compact.uniq
        if all_upload_ids.present?
          input = [input]
          input.concat(all_upload_ids.map { |upload_id| { upload_id: upload_id } })
        end

        bot =
          DiscourseAi::Personas::Bot.as(
            Discourse.system_user,
            persona: tagger_persona.class_instance.new,
            model: model,
          )

        persona_response_format = tagger_persona.response_format

        bot_ctx =
          DiscourseAi::Personas::BotContext.new(
            user: Discourse.system_user,
            skip_tool_details: true,
            feature_name: "llm_tagger",
            messages: [{ type: :user, content: input }],
          )

        llm_args = {
          feature_context: {
            automation_id: automation&.id,
            automation_name: automation&.name,
          },
        }

        llm_args[:response_format] = persona_response_format if persona_response_format.present?

        result = +""
        bot.reply(bot_ctx, llm_args: llm_args) do |partial, _, type|
          if type == :structured_output
            result = partial.to_s
          elsif type.blank?
            result << partial
          end
        end

        begin
          response = JSON.parse(result)
          suggested_tags = response["tags"] || []
          confidence = response["confidence"] || 0

          return if confidence < confidence_threshold

          if tag_mode == "manual"
            # Manual mode: validate against configured tag list
            valid_tags = suggested_tags.select { |tag| available_tags.include?(tag) }
          else
            # Discover mode: validate against site tags (with safe caching)
            cache_key =
              (
                if allow_restricted_tags
                  "discourse_ai_all_tag_names"
                else
                  "discourse_ai_visible_tag_names"
                end
              )
            all_site_tags =
              begin
                Rails
                  .cache
                  .fetch(cache_key, expires_in: 30.minutes) do
                    if allow_restricted_tags
                      Tag.order(public_topic_count: :desc).limit(300).pluck(:name)
                    else
                      # Use anonymous user guardian to respect tag restrictions
                      DiscourseTagging
                        .visible_tags(Guardian.new)
                        .order(public_topic_count: :desc)
                        .limit(300)
                        .pluck(:name)
                    end
                  end
              rescue => e
                # Fallback to direct query if cache fails
                Rails.logger.warn("llm_tagger: Cache failed (#{e.message}), using direct query")
                if allow_restricted_tags
                  Tag.order(public_topic_count: :desc).limit(300).pluck(:name)
                else
                  # Use anonymous user guardian to respect tag restrictions
                  DiscourseTagging
                    .visible_tags(Guardian.new)
                    .order(public_topic_count: :desc)
                    .limit(300)
                    .pluck(:name)
                end
              end
            valid_tags = suggested_tags.select { |tag| all_site_tags.include?(tag) }
          end
          valid_tags = valid_tags.first(max_tags)

          if valid_tags.present?
            existing_tag_count = post.topic.tags.count
            site_max_tags = SiteSetting.max_tags_per_topic
            available_slots = site_max_tags - existing_tag_count

            if available_slots > 0
              # Only take as many tags as we have slots for
              tags_to_add = valid_tags.first(available_slots)
              apply_tags_to_topic(post.topic, tags_to_add)

              Rails.logger.debug(
                "llm_tagger: Applied tags #{tags_to_add.inspect} to topic #{post.topic.id} " \
                  "with confidence #{confidence}",
              )
            else
            end
          end
        rescue JSON::ParserError => e
          Rails.logger.warn(
            "llm_tagger: Failed to parse JSON response for post #{post.id}: #{e.message}. " \
              "Response was: #{result.truncate(500)}",
          )
        end
      end

      private

      def self.apply_tags_to_topic(topic, new_tags)
        return unless SiteSetting.tagging_enabled?

        existing_tags = topic.tags.map(&:name)

        tags_to_add = new_tags - existing_tags
        return if tags_to_add.empty?

        all_tags = existing_tags + tags_to_add

        first_post = topic.posts.where(post_number: 1).first
        return unless first_post

        changes = { tags: all_tags, bypass_bump: true, skip_validations: true }

        first_post.revise(Discourse.system_user, changes)
      end
    end
  end
end
