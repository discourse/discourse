# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Actions
      class SendChatMessage < Base
        def self.identifier
          "action:send_chat_message"
        end

        def self.icon
          "comment"
        end

        def self.color_key
          "teal"
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

          Chat::CreateMessage.call(
            guardian: Discourse.system_user.guardian,
            params: {
              chat_channel_id: channel_id,
              message: message,
            },
          ) do
            on_success { { "channel_id" => channel_id, "message" => message } }
            on_failed_contract do |contract|
              raise "Invalid params: #{contract.errors.full_messages.join(", ")}"
            end
            on_model_not_found(:channel) { raise "Channel not found: #{channel_id}" }
            on_failure { raise "Failed to send chat message" }
          end
        end
      end
    end
  end
end
