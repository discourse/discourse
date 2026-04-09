# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module WaitHandlers
      class ChatApproval < Base
        handles_wait_type :chat_approval

        def self.timeout_response_items(execution)
          [
            {
              "json" => {
                "approved" => false,
                "channel_id" => execution.waiting_config&.dig("chat_channel_id"),
                "timed_out" => true,
              },
            },
          ]
        end

        def pause!(wait)
          channel_id = wait.channel_id.to_i
          wait_nonce = SecureRandom.hex(16)
          chat_message =
            self.class.send_chat_message(
              channel_id,
              wait.message_text,
              approval_blocks(step, wait, wait_nonce),
            )

          pause_execution!(
            node,
            waiting_until: wait.timeout_minutes.presence&.minutes&.from_now,
            extra_config: {
              "wait_type" => self.class.wait_type,
              "timeout_action" => wait.timeout_action,
              "chat_message_id" => chat_message.id,
              "chat_channel_id" => channel_id,
              "wait_nonce" => wait_nonce,
            },
          )
        end

        def self.send_chat_message(channel_id, message, blocks)
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

        private

        def approval_blocks(step, wait, wait_nonce)
          [
            {
              "type" => "actions",
              "elements" => [
                button_block(
                  wait.approve_label,
                  build_signed_action_id(step, "approve", wait_nonce),
                  "approve",
                ),
                button_block(
                  wait.deny_label,
                  build_signed_action_id(step, "deny", wait_nonce),
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

        def build_signed_action_id(step, decision, wait_nonce)
          node_id = step.node_id
          payload = "#{@state.execution.id}:#{node_id}:#{decision}:#{wait_nonce}"
          signature = HmacSigner.sign(payload)
          "dwf:#{@state.execution.id}:#{node_id}:#{decision}:#{wait_nonce}:#{signature}"
        end
      end
    end
  end
end
