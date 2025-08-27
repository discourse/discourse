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
        automation: nil
      )
        # Skip if manual mode but no tags provided
        return if tag_mode == "manual" && available_tags.empty?

        tagger_persona = AiPersona.find(tagger_persona_id)
        model_id = tagger_persona.default_llm_id || SiteSetting.ai_default_llm_model
        return if model_id.blank?
        model = LlmModel.find(model_id)

        if tag_mode == "manual"
          # Manual mode: provide specific tag list in prompt
          available_tags_text = "Available tags: #{available_tags.join(", ")}\n\n"
          input = "#{available_tags_text}Post to analyze:\ntitle: #{post.topic.title}\n#{post.raw}"
        else
          # Discover mode: instruct AI to use list_tags tool
          input =
            "Post to analyze:\ntitle: #{post.topic.title}\n#{post.raw}\n\nUse the list_tags tool to see available tags, then suggest appropriate ones."
        end

        if max_post_tokens.present?
          input =
            model.tokenizer_class.truncate(
              input,
              max_post_tokens,
              strict: SiteSetting.ai_strict_token_counting,
            )
        end

        if post.upload_ids.present?
          input = [input]
          input.concat(post.upload_ids.map { |upload_id| { upload_id: upload_id } })
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

        if persona_response_format.present? && !Rails.env.test?
          llm_args[:response_format] = persona_response_format
        end

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
          confidence = response["confidence"] || 0.0

          return if confidence < confidence_threshold

          if tag_mode == "manual"
            # Manual mode: validate against configured tag list
            valid_tags = suggested_tags.select { |tag| available_tags.include?(tag) }
          else
            # Discover mode: validate against all existing site tags (with safe caching)
            all_site_tags =
              begin
                Rails
                  .cache
                  .fetch("discourse_ai_all_tag_names", expires_in: 30.minutes) { Tag.pluck(:name) }
              rescue => e
                # Fallback to direct query if cache fails
                Rails.logger.warn("llm_tagger: Cache failed (#{e.message}), using direct query")
                Tag.pluck(:name)
              end
            valid_tags = suggested_tags.select { |tag| all_site_tags.include?(tag) }
          end
          valid_tags = valid_tags.first(max_tags)

          if valid_tags.present?
            existing_tag_count = post.topic.tags.count
            site_max_tags = SiteSetting.max_tags_per_topic
            available_slots = site_max_tags - existing_tag_count

            Rails.logger.info(
              "llm_tagger: Topic #{post.topic.id} has #{existing_tag_count}/#{site_max_tags} tags, " \
                "#{available_slots} slots available. Suggested tags: #{valid_tags.inspect}",
            )

            if available_slots > 0
              # Only take as many tags as we have slots for
              tags_to_add = valid_tags.first(available_slots)
              apply_tags_to_topic(post.topic, tags_to_add)

              Rails.logger.info(
                "llm_tagger: Applied tags #{tags_to_add.inspect} to topic #{post.topic.id} " \
                  "with confidence #{confidence}. Had #{available_slots} slots available.",
              )
            else
              Rails.logger.info(
                "llm_tagger: Skipped tagging topic #{post.topic.id} - already at max tags " \
                  "(#{existing_tag_count}/#{site_max_tags})",
              )
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
