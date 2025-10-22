# frozen_string_literal: true
module DiscourseAi
  module AiHelper
    class EntryPoint
      def inject_into(plugin)
        plugin.register_seedfu_fixtures(
          Rails.root.join("plugins", "discourse-ai", "db", "fixtures", "ai_helper"),
        )

        plugin.add_to_serializer(:current_user, :can_use_assistant) do
          scope.user.in_any_groups?(SiteSetting.composer_ai_helper_allowed_groups_map)
        end

        plugin.add_to_serializer(:current_user, :can_use_assistant_in_post) do
          scope.user.in_any_groups?(SiteSetting.post_ai_helper_allowed_groups_map)
        end

        plugin.add_to_serializer(:current_user, :can_use_custom_prompts) do
          return [] if !SiteSetting.ai_helper_enabled

          custom_prompt_allowed_group_ids =
            DB.query_single(
              "SELECT allowed_group_ids FROM ai_personas WHERE id = :customp_prompt_persona_id",
              customp_prompt_persona_id: SiteSetting.ai_helper_custom_prompt_persona,
            ).flatten

          scope.user.in_any_groups?(custom_prompt_allowed_group_ids)
        end

        plugin.on(:chat_message_created) do |message, channel, user, extra|
          next unless SiteSetting.ai_helper_enabled
          next unless SiteSetting.ai_helper_automatic_chat_thread_title
          next if extra[:thread].blank?
          next if extra[:thread].title.present?

          reply_count = extra[:thread].replies.count

          if reply_count.between?(1, 4)
            ::Jobs.enqueue_in(
              SiteSetting.ai_helper_automatic_chat_thread_title_delay.minutes,
              :generate_chat_thread_title,
              thread_id: extra[:thread].id,
            )
          elsif reply_count >= 5
            ::Jobs.enqueue(:generate_chat_thread_title, thread_id: extra[:thread].id)
          end
        end

        plugin.add_to_serializer(
          :current_user,
          :ai_helper_prompts,
          include_condition: -> { SiteSetting.ai_helper_enabled && scope.authenticated? },
        ) do
          ActiveModel::ArraySerializer.new(
            DiscourseAi::AiHelper::Assistant.new.available_prompts(scope.user),
            root: false,
          )
        end
      end
    end
  end
end
