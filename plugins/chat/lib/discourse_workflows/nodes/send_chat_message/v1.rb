# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module SendChatMessage
        class V1 < DiscourseWorkflows::NodeType
          include ChatChannelSelection

          description(
            name: "action:send_chat_message",
            version: "1.0",
            defaults: {
              icon: "comment",
              color: "teal",
            },
            group: "discourse_actions",
            available: -> { SiteSetting.chat_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_chat",
            capabilities: {
              run_scope: "per_item",
            },
            properties: {
              channel_id: {
                type: :integer,
                required: true,
                type_options: {
                  load_options_method: "chat_channels",
                },
                ui: {
                  control: :combo_box,
                  dynamic_value: :chat_channel_id,
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
              message: {
                type: :string,
                required: true,
                ui: {
                  control: :textarea,
                },
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
            items =
              exec_ctx.input_items.map.with_index do |_item, item_index|
                config = {
                  "channel_id" => exec_ctx.get_node_parameter("channel_id", item_index),
                  "message" => exec_ctx.get_node_parameter("message", item_index),
                }
                result = process(config)
                wrap(result)
              end
            [items]
          end

          private

          def process(config)
            channel_id = config["channel_id"]
            message = config["message"]
            channel = selectable_chat_channel(channel_id)

            if channel.blank?
              raise_node_error!(
                I18n.t(
                  "discourse_workflows.errors.send_chat_message.channel_not_found",
                  channel_id: channel_id,
                ),
              )
            end

            Chat::CreateMessage.call(
              guardian: Discourse.system_user.guardian,
              params: {
                chat_channel_id: channel.id,
                message: message,
              },
            ) do
              on_success { { "channel_id" => channel.id, "message" => message } }
              on_failed_contract do |contract|
                raise_node_error!(
                  I18n.t(
                    "discourse_workflows.errors.send_chat_message.invalid_params",
                    errors: contract.errors.full_messages.join(", "),
                  ),
                )
              end
              on_model_not_found(:channel) do
                raise_node_error!(
                  I18n.t(
                    "discourse_workflows.errors.send_chat_message.channel_not_found",
                    channel_id: channel_id,
                  ),
                )
              end
              on_failure do
                raise_node_error!(I18n.t("discourse_workflows.errors.send_chat_message.failed"))
              end
            end
          end
        end
      end
    end
  end
end
