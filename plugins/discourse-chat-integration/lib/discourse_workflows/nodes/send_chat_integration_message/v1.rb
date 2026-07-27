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
                    "post_id" => {
                      "type" => %w[integer null],
                    },
                    "custom_message" => {
                      "type" => "boolean",
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
              post_id: {
                type: :string,
                required: false,
                default: "={{ $trigger.post.id }}",
              },
              message: {
                type: :string,
                required: false,
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
                  "post_id" => exec_ctx.get_node_parameter("post_id", item_index),
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

            post = ::Post.find_by(id: config["post_id"]) if config["post_id"].present?
            if config["post_id"].present? && post.blank?
              raise_node_error!(
                I18n.t(
                  "discourse_workflows.errors.send_chat_integration_message.post_not_found",
                  post_id: config["post_id"],
                ),
                item_index: item_index,
              )
            end

            if post.blank? && config["message"].blank?
              raise_node_error!(
                I18n.t(
                  "discourse_workflows.errors.send_chat_integration_message.post_or_message_required",
                ),
                item_index: item_index,
              )
            end

            # post_id accepts expressions, so enforce visibility and post-type guards
            # before relaying content to an external service.
            if post.present? && !sendable_post?(post)
              raise_node_error!(
                I18n.t(
                  "discourse_workflows.errors.send_chat_integration_message.post_not_allowed",
                  post_id: config["post_id"],
                ),
                item_index: item_index,
              )
            end

            target = build_target(post, config["message"])
            begin
              provider.trigger_notification(target, channel, nil)
            rescue DiscourseChatIntegration::ProviderError => error
              raise_node_error!(
                provider_error_message(error, channel.provider),
                item_index: item_index,
              )
            end

            {
              "channel_id" => channel.id,
              "provider" => channel.provider,
              "post_id" => post&.id,
              "custom_message" => config["message"].present?,
            }
          end

          def sendable_post?(post)
            post.post_type == ::Post.types[:regular] &&
              DiscourseChatIntegration::Manager.guardian.can_see?(post)
          end

          def build_target(post, message)
            return post if message.blank?

            DiscourseChatIntegration::ChatIntegrationReferencePost.new(
              user: post&.user || Discourse.system_user,
              topic: post&.topic,
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
