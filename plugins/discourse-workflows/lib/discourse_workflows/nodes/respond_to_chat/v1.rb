# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module RespondToChat
      class V1 < NodeType
        description(
          name: "action:respond_to_chat",
          version: "1.0",
          defaults: {
            icon: "reply",
            color: "teal",
          },
          group: "discourse_actions",
          available: -> { ChatConversation.chat_available? },
          unavailable_reason_key: "discourse_workflows.node_unavailable.chat_disabled",
          output_contracts: [
            {
              schema:
                Schema.document(
                  "channel_id" => {
                    "type" => "integer",
                  },
                  "message_id" => {
                    "type" => "integer",
                  },
                  "message" => {
                    "type" => "string",
                  },
                ),
            },
          ],
          properties: {
            message: {
              type: :string,
              required: true,
              ui: {
                control: :textarea,
              },
            },
          },
        )

        def execute(exec_ctx)
          items = exec_ctx.each_item { |_item, item_index| wrap(respond(exec_ctx, item_index)) }

          [items]
        end

        private

        def respond(exec_ctx, item_index)
          conversation = triggering_conversation(exec_ctx, item_index)
          if !conversation&.channel&.open?
            raise_node_error!(
              I18n.t("discourse_workflows.errors.respond_to_chat.no_conversation"),
              item_index:,
            )
          end

          raw = exec_ctx.get_node_parameter("message", item_index)
          message = post_as_bot(conversation, raw, item_index)

          { "channel_id" => conversation.channel_id, "message_id" => message.id, "message" => raw }
        end

        # The reply goes to the conversation whose trigger started this run and to no other, so
        # a run can never write in another member's chat.
        def triggering_conversation(exec_ctx, item_index)
          channel_id =
            Integer(
              exec_ctx.evaluate_expression("={{ $trigger.channel_id }}", item_index),
              exception: false,
            )
          return if channel_id.nil?

          ChatConversation.find_by(
            channel_id:,
            workflow_id: exec_ctx.get_workflow.id,
            trigger_node_id: exec_ctx.trigger_node_id,
          )
        end

        def post_as_bot(conversation, raw, item_index)
          ::ChatSDK::Message.create(
            raw:,
            channel_id: conversation.channel_id,
            guardian: conversation.bot_user.guardian,
            enforce_membership: true,
          )
        rescue RuntimeError => e
          raise_node_error!(
            I18n.t("discourse_workflows.errors.respond_to_chat.failed", reason: e.message),
            item_index:,
          )
        end
      end
    end
  end
end
