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
          scope.user.in_any_groups?(SiteSetting.ai_helper_custom_prompts_allowed_groups_map)
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

        plugin.add_to_serializer(:current_user, :user_allowed_ai_auto_image_captions) do
          scope.user.in_any_groups?(SiteSetting.ai_auto_image_caption_allowed_groups_map)
        end

        UserUpdater::OPTION_ATTR.push(:auto_image_caption)
        plugin.add_to_serializer(
          :user_option,
          :auto_image_caption,
          include_condition: -> do
            SiteSetting.ai_helper_enabled &&
              SiteSetting.ai_helper_enabled_features.include?("image_caption") &&
              scope.user.in_any_groups?(SiteSetting.ai_auto_image_caption_allowed_groups_map)
          end,
        ) { object.auto_image_caption }

        plugin.add_to_serializer(
          :current_user_option,
          :auto_image_caption,
          include_condition: -> do
            SiteSetting.ai_helper_enabled &&
              SiteSetting.ai_helper_enabled_features.include?("image_caption") &&
              scope.user.in_any_groups?(SiteSetting.ai_auto_image_caption_allowed_groups_map)
          end,
        ) { object.auto_image_caption }
      end
    end
  end
end
