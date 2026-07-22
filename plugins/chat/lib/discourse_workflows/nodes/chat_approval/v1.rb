# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module ChatApproval
        class V1 < DiscourseWorkflows::NodeType
          include ChatChannelSelection

          APPROVAL_OUTPUT_SCHEMA = {
            "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
            "type" => "object",
            "properties" => {
              "approved" => {
                "type" => "boolean",
              },
              "channel_id" => {
                "type" => "integer",
              },
            },
          }.freeze

          description(
            name: "action:chat_approval",
            version: "1.0",
            defaults: {
              icon: "comments",
              color: "cyan",
            },
            group: "human_review",
            available: -> { SiteSetting.chat_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_chat",
            capabilities: {
              waits_for_resume: true,
            },
            output_contracts: [
              {
                schema: APPROVAL_OUTPUT_SCHEMA,
                variants: [
                  {
                    schema: APPROVAL_OUTPUT_SCHEMA,
                    mode: :union,
                    display_options: {
                      show: {
                        timeout_minutes: [{ condition: { exists: true } }],
                      },
                      hide: {
                        timeout_action: ["fail"],
                      },
                    },
                  },
                ],
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
                type_options: {
                  load_options_method: "chat_channels",
                },
                no_data_expression: true,
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  filterable: true,
                  value_property: :id,
                  name_property: :name,
                  set_from_option: {
                    channel_name: "name",
                  },
                },
              },
              channel_name: {
                type: :string,
                ui: {
                  hidden: true,
                },
              },
              timeout_minutes: {
                type: :integer,
                required: false,
                min: 1,
              },
              timeout_action: {
                type: :options,
                required: false,
                options: %w[deny fail],
                default: "deny",
                no_data_expression: true,
              },
            },
          )

          def self.load_options_context(context)
            case context.method_name
            when "chat_channels"
              ChatChannelSelection.load_options(context)
            end
          end

          def execute(exec_ctx)
            message_text = exec_ctx.get_node_parameter("message", 0)
            approve_label =
              exec_ctx.get_node_parameter("approve_label", 0).presence ||
                I18n.t("discourse_workflows.chat_approval.default_approve_label")
            deny_label =
              exec_ctx.get_node_parameter("deny_label", 0).presence ||
                I18n.t("discourse_workflows.chat_approval.default_deny_label")
            channel_id = exec_ctx.get_node_parameter("channel_id", 0).to_i
            timeout_minutes = exec_ctx.get_node_parameter("timeout_minutes", 0).presence&.to_i
            if timeout_minutes && timeout_minutes < 1
              raise_node_error!(
                I18n.t("discourse_workflows.errors.chat_approval.timeout_must_be_positive"),
              )
            end

            approve_action_id = exec_ctx.resume_action_id("approve")
            deny_action_id = exec_ctx.resume_action_id("deny")

            blocks = approval_blocks(approve_action_id, deny_action_id, approve_label, deny_label)
            send_chat_message(channel_id, message_text, blocks)

            exec_ctx.put_execution_to_wait(timeout_minutes&.minutes&.from_now)
            [exec_ctx.input_items]
          end

          private

          def send_chat_message(channel_id, message, blocks)
            channel = selectable_chat_channel(channel_id)

            if channel.blank?
              raise_node_error!(
                I18n.t(
                  "discourse_workflows.errors.chat_approval.channel_not_found",
                  channel_id: channel_id,
                ),
              )
            end

            Chat::CreateMessage.call(
              guardian: Discourse.system_user.guardian,
              params: {
                chat_channel_id: channel.id,
                message: message,
                blocks: blocks,
              },
            ) do |result|
              on_success { return result.message_instance }
              on_model_not_found(:channel) do
                raise_node_error!(
                  I18n.t(
                    "discourse_workflows.errors.chat_approval.channel_not_found",
                    channel_id: channel_id,
                  ),
                )
              end
              on_failed_contract do |contract|
                raise_node_error!(
                  I18n.t(
                    "discourse_workflows.errors.chat_approval.invalid_params",
                    errors: contract.errors.full_messages.join(", "),
                  ),
                )
              end
              on_failure do
                raise_node_error!(
                  I18n.t(
                    "discourse_workflows.errors.chat_approval.failed",
                    steps: result.inspect_steps,
                  ),
                )
              end
            end
          end

          def approval_blocks(approve_token, deny_token, approve_label, deny_label)
            [
              {
                "type" => "actions",
                "elements" => [
                  button_block(approve_label, approve_token, "approve"),
                  button_block(deny_label, deny_token, "deny"),
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
        end
      end
    end
  end
end
