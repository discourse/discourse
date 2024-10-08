# frozen_string_literal: true

module Chat
  class SendMessageAutomationScript
    def self.call
      proc do
        field :chat_channel_id, component: :text, required: true
        field :message, component: :message, required: true, accepts_placeholders: true
        field :sender, component: :user

        placeholder :channel_name

        triggerables %i[recurring topic_tags_changed post_created_edited]

        script do |context, fields, automation|
          sender = User.find_by(username: fields.dig("sender", "value")) || Discourse.system_user
          channel = Chat::Channel.find_by(id: fields.dig("chat_channel_id", "value"))
          placeholders = { channel_name: channel.title(sender) }.merge(
            context["placeholders"] || {},
          )

          creator =
            ::Chat::CreateMessage.call(
              chat_channel_id: channel.id,
              guardian: sender.guardian,
              message: utils.apply_placeholders(fields.dig("message", "value"), placeholders),
            )

          if creator.failure?
            Rails.logger.warn "[discourse-automation] Chat message failed to send:\n#{creator.inspect_steps.inspect}\n#{creator.inspect_steps.error}"
          end
        end
      end
    end
  end
end
