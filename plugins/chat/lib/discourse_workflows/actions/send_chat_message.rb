# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Actions
      class SendChatMessage < Base
        def self.identifier
          "action:send_chat_message"
        end

        def self.output_schema
          { channel_id: :integer, message: :string }
        end

        def self.configuration_schema
          {
            channel_id: {
              type: :integer,
              required: true,
            },
            message: {
              type: :string,
              required: true,
              ui: {
                control: :textarea,
                rows: 6,
              },
            },
          }
        end

        def execute_single(context, item:, config:)
          channel_id = config["channel_id"]
          message = config["message"]

          channel = Chat::Channel.find(channel_id)
          creator =
            Chat::CreateMessage.call(
              guardian: Discourse.system_user.guardian,
              params: {
                chat_channel_id: channel.id,
                message: message,
              },
            )

          raise "Failed to send chat message" if creator.failure?

          { "channel_id" => channel.id, "message" => message }
        end
      end
    end
  end
end
