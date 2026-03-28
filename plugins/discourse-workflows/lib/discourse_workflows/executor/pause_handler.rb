# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class PauseHandler
      def initialize(state)
        @state = state
      end

      def pause!(wait)
        step = @state.waiting_step
        node = @state.waiting_node

        raise ArgumentError, "waiting step is required to pause execution" if step.nil?
        raise ArgumentError, "waiting node is required to pause execution" if node.nil?

        step.update!(status: :waiting)

        if wait.form?
          pause_for_form!(wait, step, node)
        else
          pause_for_approval!(wait, step, node)
        end
      end

      private

      def pause_for_approval!(wait, step, node)
        channel_id = wait.channel_id.to_i
        chat_message = send_approval_chat_message(channel_id, step, wait)

        pause_execution!(
          node,
          waiting_until:
            wait.timeout_minutes.present? ? wait.timeout_minutes.minutes.from_now : nil,
          extra_config: {
            "timeout_action" => wait.timeout_action,
            "chat_message_id" => chat_message.id,
            "chat_channel_id" => channel_id,
          },
        )
      end

      def pause_for_form!(wait, _step, node)
        pause_execution!(
          node,
          extra_config: {
            "wait_type" => "form",
            "form_title" => wait.form_title,
            "form_description" => wait.form_description,
            "form_fields" => wait.form_fields,
          },
        )

        MessageBus.publish(
          Executor.form_channel(@state.execution.id),
          { status: "waiting_for_form" },
        )

        @state.execution
      end

      def pause_execution!(node, waiting_until: nil, extra_config: {})
        @state.execution.update!(
          status: :waiting,
          context: @state.context,
          waiting_node_id: node.id,
          waiting_until: waiting_until,
          waiting_config: @state.waiting_config.merge(extra_config),
        )

        @state.execution
      end

      def send_approval_chat_message(channel_id, step, wait)
        result =
          Chat::CreateMessage.call(
            guardian: Discourse.system_user.guardian,
            params: {
              chat_channel_id: channel_id,
              message: wait.message_text,
              blocks: approval_blocks(step, wait),
            },
          )

        raise "Failed to send approval chat message" if result.failure?
        result.message_instance
      end

      def approval_blocks(step, wait)
        [
          {
            "type" => "actions",
            "elements" => [
              button_block(
                wait.approve_label,
                build_signed_action_id(step.id, "approve"),
                "approve",
              ),
              button_block(wait.deny_label, build_signed_action_id(step.id, "deny"), "deny"),
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

      def build_signed_action_id(step_id, decision)
        payload = "#{@state.execution.id}:#{step_id}"
        signature = HmacSigner.sign(payload)
        "dwf:#{@state.execution.id}:#{step_id}:#{decision}:#{signature}"
      end
    end
  end
end
