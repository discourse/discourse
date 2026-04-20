# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module SendChatMessage
        class V1 < NodeType
          def self.identifier
            "action:send_chat_message"
          end

          def self.icon
            "comment"
          end

          def self.color_key
            "teal"
          end

          def self.available?
            SiteSetting.chat_enabled
          end

          def self.unavailable_reason_key
            "discourse_workflows.node_unavailable.requires_chat" unless available?
          end

          def self.output_schema
            { channel_id: :integer, message: :string }
          end

          def self.property_schema
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

          def execute(exec_ctx)
            items =
              exec_ctx.input_items.map do |item|
                config = exec_ctx.get_parameters(item)
                result = process(config)
                Item.new(result).to_h
              end
            ItemContract.validate_items!(items, source: self.class.identifier)
            [items]
          end

          private

          def process(config)
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
end
