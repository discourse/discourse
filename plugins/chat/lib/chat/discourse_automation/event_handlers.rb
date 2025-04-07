# frozen_string_literal: true

module Chat
  module DiscourseAutomation
    module EventHandlers
      def self.handle_chat_message_created_edited(chat_message, action)
        # disallow bots (protection for cases where user is nil somehow)
        return if chat_message.user_id.to_i <= 0
        channel = chat_message.chat_channel
        return if channel.blank?

        name = ::Chat::DiscourseAutomation::Triggers::CHAT_MESSAGE_CREATED_EDITED

        ::DiscourseAutomation::Automation
          .where(trigger: name, enabled: true)
          .find_each do |automation|
            action_type = automation.trigger_field("action_type")
            selected_action = action_type["value"]&.to_sym

            if selected_action
              next if selected_action == :created && action != :create
              next if selected_action == :edited && action != :edit
            end

            restricted_channels = automation.trigger_field("restricted_channels")
            if restricted_channels["value"].present?
              next if !restricted_channels["value"].include?(channel.id)
            end

            restricted_group_ids = automation.trigger_field("restricted_groups")["value"]
            if restricted_group_ids.present? &&
                 !chat_message.user.in_any_groups?(restricted_group_ids)
              next
            end

            message_url =
              "#{Discourse.base_url}/chat/c/#{channel.slug || channel.id}/-/#{chat_message.id}"

            automation.trigger!(
              "kind" => name,
              "action" => action,
              "chat_message" => chat_message,
              "user" => chat_message.user,
              "placeholders" => {
                "message_url" => message_url,
                "message_text" => chat_message.message,
                "channel_name" => channel.name,
                "channel_slug" => channel.slug,
              },
            )
          end
      end
    end
  end
end
