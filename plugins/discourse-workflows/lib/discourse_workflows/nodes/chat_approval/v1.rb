# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ChatApproval
      class V1 < NodeType
        def self.identifier
          "action:chat_approval"
        end

        def self.icon
          "comments"
        end

        def self.color
          "cyan"
        end

        def self.group
          "human_review"
        end

        def self.output_schema
          { approved: :boolean, channel_id: :integer }
        end

        def self.property_schema
          {
            message: {
              type: :string,
              required: true,
              ui: {
                control: :textarea,
                rows: 4,
              },
            },
            approve_label: {
              type: :string,
              required: false,
            },
            deny_label: {
              type: :string,
              required: false,
            },
            channel_id: {
              type: :integer,
              required: true,
            },
            timeout_minutes: {
              type: :integer,
              required: false,
            },
            timeout_action: {
              type: :options,
              required: false,
              options: %w[deny fail],
              default: "deny",
              ui: {
                expression: false,
              },
            },
          }
        end

        def execute(exec_ctx)
          item = exec_ctx.input_items.first || { "json" => {} }
          config = exec_ctx.get_parameters(item)

          message_text = config.fetch("message")
          approve_label = config["approve_label"].presence || "Approve"
          deny_label = config["deny_label"].presence || "Deny"
          channel_id = config.fetch("channel_id").to_i
          timeout_minutes = config["timeout_minutes"].presence&.to_i
          timeout_action = config.fetch("timeout_action") { "deny" }

          wait_nonce = SecureRandom.hex(16)
          execution_id = exec_ctx.execution_id
          node_id = exec_ctx.node_id

          blocks = approval_blocks(execution_id, node_id, approve_label, deny_label, wait_nonce)
          chat_message = send_chat_message(channel_id, message_text, blocks)

          WaitForResume.new(
            waiting_until: timeout_minutes&.minutes&.from_now,
            waiting_config: {
              "wait_type" => "chat_approval",
              "timeout_action" => timeout_action,
              "chat_message_id" => chat_message.id,
              "chat_channel_id" => channel_id,
              "wait_nonce" => wait_nonce,
              "timeout_response_items" => [
                {
                  "json" => {
                    "approved" => false,
                    "channel_id" => channel_id,
                    "timed_out" => true,
                  },
                },
              ],
            },
          )
        end

        private

        def send_chat_message(channel_id, message, blocks)
          Chat::CreateMessage.call(
            guardian: Discourse.system_user.guardian,
            params: {
              chat_channel_id: channel_id,
              message: message,
              blocks: blocks,
            },
          ) do |result|
            on_success { return result.message_instance }
            on_model_not_found(:channel) do
              raise "Chat message failed: channel #{channel_id} not found"
            end
            on_failed_contract do |contract|
              raise "Chat message failed: #{contract.errors.full_messages.join(", ")}"
            end
            on_failure { raise "Chat message failed: #{result.inspect_steps}" }
          end
        end

        def approval_blocks(execution_id, node_id, approve_label, deny_label, wait_nonce)
          [
            {
              "type" => "actions",
              "elements" => [
                button_block(
                  approve_label,
                  build_signed_action_id(execution_id, node_id, "approve", wait_nonce),
                  "approve",
                ),
                button_block(
                  deny_label,
                  build_signed_action_id(execution_id, node_id, "deny", wait_nonce),
                  "deny",
                ),
              ],
            },
          ]
        end

        def button_block(label, action_id, value)
          {
            "type" => "button",
            "text" => {
              "type" => "plain_text",
              "text" => label,
            },
            "action_id" => action_id,
            "value" => value,
          }
        end

        def build_signed_action_id(execution_id, node_id, decision, wait_nonce)
          payload = "#{execution_id}:#{node_id}:#{decision}:#{wait_nonce}"
          signature = DiscourseWorkflows::HmacSigner.sign(payload)
          "dwf:#{execution_id}:#{node_id}:#{decision}:#{wait_nonce}:#{signature}"
        end
      end
    end
  end
end
