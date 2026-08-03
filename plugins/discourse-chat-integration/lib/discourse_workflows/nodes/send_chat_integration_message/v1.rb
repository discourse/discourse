# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module SendChatIntegrationMessage
        class V1 < DiscourseWorkflows::NodeType
          include ChatIntegrationChannelSelection

          description(
            name: "action:send_chat_integration_message",
            version: "1.0",
            defaults: {
              icon: "paper-plane",
              color: "green",
            },
            group: "discourse_actions",
            available: -> { SiteSetting.chat_integration_enabled },
            unavailable_reason_key:
              "discourse_workflows.node_unavailable.requires_chat_integration",
            capabilities: {
              run_scope: "per_item",
            },
            output_contracts: [
              {
                schema: {
                  "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
                  "type" => "object",
                  "properties" => {
                    "channel_id" => {
                      "type" => "integer",
                    },
                    "provider" => {
                      "type" => "string",
                    },
                  },
                },
              },
            ],
            properties: {
              channel_id: {
                type: :integer,
                required: true,
                type_options: {
                  load_options_method: "chat_integration_channels",
                },
                ui: {
                  control: :combo_box,
                  dynamic_value: :chat_channel_id,
                },
                control_options: {
                  action_icon: "wrench",
                  action_label: "discourse_workflows.send_chat_integration_message.configure",
                  action_route: "adminPlugins.show.discourse-chat-integration-providers",
                  action_route_models: ["discourse-chat-integration"],
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
                default: "={{ $trigger.post.excerpt }}",
                ui: {
                  control: :textarea,
                },
              },
            },
          )

          def self.load_options_context(context)
            case context.method_name
            when "chat_integration_channels"
              ChatIntegrationChannelSelection.load_options(context)
            end
          end

          def execute(exec_ctx)
            items =
              exec_ctx.input_items.map.with_index do |_item, item_index|
                config = {
                  "channel_id" => exec_ctx.get_node_parameter("channel_id", item_index),
                  "message" => exec_ctx.get_node_parameter("message", item_index),
                }
                wrap(process(config, item_index))
              end
            [items]
          end

          private

          def process(config, item_index)
            channel = selectable_channel(config["channel_id"])
            if channel.blank?
              raise_node_error!(
                I18n.t(
                  "discourse_workflows.errors.send_chat_integration_message.channel_not_found",
                  channel_id: config["channel_id"],
                ),
                item_index: item_index,
              )
            end

            provider = DiscourseChatIntegration::Provider.get_by_name(channel.provider)
            if provider.blank? || !DiscourseChatIntegration::Provider.is_enabled(provider)
              raise_node_error!(
                I18n.t(
                  "discourse_workflows.errors.send_chat_integration_message.provider_disabled",
                  provider: channel.provider,
                ),
                item_index: item_index,
              )
            end

            if config["message"].blank?
              raise_node_error!(
                I18n.t("discourse_workflows.errors.send_chat_integration_message.message_required"),
                item_index: item_index,
              )
            end

            target = build_target(config["message"])
            begin
              provider.trigger_notification(target, channel, nil)
            rescue DiscourseChatIntegration::ProviderError => error
              raise_node_error!(
                provider_error_message(error, channel.provider),
                item_index: item_index,
              )
            end

            { "channel_id" => channel.id, "provider" => channel.provider }
          end

          def build_target(message)
            DiscourseChatIntegration::ChatIntegrationReferencePost.new(
              user: Discourse.system_user,
              kind: :workflow,
              raw: message,
            )
          end

          def provider_error_message(error, provider)
            details = provider_error_details(error)
            translation_key = details.present? ? "provider_failed_with_details" : "provider_failed"

            I18n.t(
              "discourse_workflows.errors.send_chat_integration_message.#{translation_key}",
              provider: provider.humanize,
              details: details,
            )
          end

          def provider_error_details(error)
            info = error.info || {}
            error_key = info[:error_key] || info["error_key"]
            return I18n.t(error_key) if error_key.present? && I18n.exists?(error_key)

            response_error = provider_response_error(info[:response_body] || info["response_body"])
            return response_error.humanize if response_error.present?
            return error_key.split(".").last.humanize if error_key.present?

            error.message if error.message.present? && error.message != error.class.name
          end

          def provider_response_error(response_body)
            response =
              case response_body
              when Hash
                response_body
              when String
                JSON.parse(response_body)
              else
                return
              end

            value = response["error"] || response[:error]
            value if value.is_a?(String) && value.match?(/\A[a-zA-Z0-9_.-]{1,100}\z/)
          rescue JSON::ParserError
            nil
          end
        end
      end
    end
  end
end
