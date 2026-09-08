# frozen_string_literal: true

require_relative "../../../chat/schemas/message_blocks"

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module ChatApproval
        class V2 < V1
          MAX_BUTTONS = 10
          MAX_LABEL_LENGTH = 75
          MAX_VALUE_LENGTH = 2000
          MAX_ICON_LENGTH = Chat::Schemas::BUTTON_ICON_MAX_LENGTH
          BUTTON_STYLES = Chat::Schemas::BUTTON_STYLES
          TIMEOUT_ACTIONS = %w[continue fail].freeze
          ACTION_IDS = Array.new(MAX_BUTTONS) { |index| "button_#{index}" }.freeze

          CLICK_OUTPUT_SCHEMA = {
            "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
            "type" => "object",
            "properties" => {
              "value" => {
                "type" => "string",
              },
              "channel" => {
                "type" => "object",
                "properties" => Chat::WorkflowChannelSerializer::PROPERTIES,
              },
              "user" => {
                "type" => "object",
                "properties" => DiscourseWorkflows::Schema::BASIC_USER_PROPERTIES,
              },
            },
          }.freeze

          description(
            name: "action:chat_approval",
            version: "2.0",
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
                schema: CLICK_OUTPUT_SCHEMA,
                variants: [
                  {
                    schema: CLICK_OUTPUT_SCHEMA,
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
            properties: -> do
              {
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
                message: {
                  type: :string,
                  required: true,
                  ui: {
                    control: :textarea,
                  },
                },
                buttons: {
                  type: :fixed_collection,
                  required: true,
                  default: default_buttons,
                  max_items: MAX_BUTTONS,
                  type_options: {
                    multiple_values: true,
                    sortable: true,
                  },
                  ui: {
                    singular_name: "button",
                  },
                  options: [
                    {
                      name: "values",
                      values: {
                        label: {
                          type: :string,
                          required: true,
                          no_data_expression: true,
                        },
                        value: {
                          type: :string,
                          required: true,
                          no_data_expression: true,
                        },
                        style: {
                          type: :options,
                          required: false,
                          options: BUTTON_STYLES,
                          no_data_expression: true,
                          control_options: {
                            none: "discourse_workflows.chat_approval.style_none",
                          },
                        },
                        icon: {
                          type: :icon,
                          required: false,
                          no_data_expression: true,
                        },
                      },
                    },
                  ],
                },
                timeout_minutes: {
                  type: :integer,
                  required: false,
                  min: 1,
                },
                timeout_action: {
                  type: :options,
                  required: false,
                  options: TIMEOUT_ACTIONS,
                  default: "continue",
                  no_data_expression: true,
                },
              }
            end,
          )

          class << self
            def default_button_rows
              [
                {
                  "label" => I18n.t("discourse_workflows.chat_approval.default_approve_label"),
                  "value" => "approve",
                },
                {
                  "label" => I18n.t("discourse_workflows.chat_approval.default_deny_label"),
                  "value" => "deny",
                },
              ]
            end

            def default_buttons
              { "values" => default_button_rows }
            end

            def button_rows(parameters)
              value = DiscourseWorkflows::CollectionParameters.fetch_value(parameters, :buttons)
              value = default_buttons if value.nil?
              DiscourseWorkflows::CollectionParameters
                .rows_from_value(value)
                .map { |row| row.respond_to?(:deep_stringify_keys) ? row.deep_stringify_keys : row }
            end

            def allowed_actions(parameters)
              ACTION_IDS.first(button_rows(parameters).size)
            end

            def button_value(parameters, action)
              index = ACTION_IDS.index(action.to_s)
              return if index.nil?

              row = button_rows(parameters)[index]
              row["value"].to_s if row.is_a?(Hash)
            end

            def valid_interaction?(interaction, action:, parameters:)
              configured_channel_id =
                Integer(
                  DiscourseWorkflows::CollectionParameters.fetch_value(parameters, :channel_id),
                  exception: false,
                )
              return false if configured_channel_id.nil?

              configured_value = button_value(parameters, action)
              action_id = interaction.action["action_id"].to_s
              message_action =
                interaction
                  .message
                  .blocks
                  &.filter_map { |block| block["elements"] }
                  .to_a
                  .flatten
                  .find { |element| element["action_id"].to_s == action_id }

              configured_value.present? &&
                interaction.message.chat_channel_id == configured_channel_id &&
                interaction.action["value"].to_s == configured_value &&
                message_action == interaction.action
            end

            def resume_user(interaction)
              interaction.user
            end

            def response_items(action:, interaction:)
              if ACTION_IDS.exclude?(action.to_s)
                raise ArgumentError, "Unsupported chat approval action: #{action}"
              end

              user = interaction.user
              channel = interaction.message.chat_channel
              scope = user.guardian
              channel_data =
                Chat::WorkflowChannelSerializer.new(channel, scope: scope, root: false).as_json
              user_data = BasicUserSerializer.new(user, scope: scope, root: false).as_json

              [
                DiscourseWorkflows::Item.wrap(
                  {
                    value: interaction.action["value"].to_s,
                    channel: channel_data,
                    user: user_data,
                  },
                  paired_item: 0,
                ),
              ]
            end

            def validate_configuration(configuration, errors)
              button_validation_errors(button_rows(configuration)).each do |message|
                errors.add(:base, message)
              end
            end

            def button_validation_errors(rows)
              errors = []

              if rows.empty?
                errors << I18n.t("discourse_workflows.errors.chat_approval.buttons_required")
                return errors
              end

              if rows.length > MAX_BUTTONS
                errors << I18n.t(
                  "discourse_workflows.errors.chat_approval.too_many_buttons",
                  max: MAX_BUTTONS,
                )
              end

              rows.each_with_index do |row, index|
                label = row.is_a?(Hash) ? row["label"].to_s : ""
                value = row.is_a?(Hash) ? row["value"].to_s : ""
                style = row.is_a?(Hash) ? row["style"].to_s : ""
                icon = row.is_a?(Hash) ? row["icon"].to_s : ""
                position = index + 1

                if label.blank?
                  errors << I18n.t(
                    "discourse_workflows.errors.chat_approval.button_label_required",
                    position: position,
                  )
                elsif label.length > MAX_LABEL_LENGTH
                  errors << I18n.t(
                    "discourse_workflows.errors.chat_approval.button_label_too_long",
                    position: position,
                    max: MAX_LABEL_LENGTH,
                  )
                end

                if value.blank?
                  errors << I18n.t(
                    "discourse_workflows.errors.chat_approval.button_value_required",
                    position: position,
                  )
                elsif value.length > MAX_VALUE_LENGTH
                  errors << I18n.t(
                    "discourse_workflows.errors.chat_approval.button_value_too_long",
                    position: position,
                    max: MAX_VALUE_LENGTH,
                  )
                end

                if style.present? && BUTTON_STYLES.exclude?(style)
                  errors << I18n.t(
                    "discourse_workflows.errors.chat_approval.button_style_invalid",
                    position: position,
                    styles: BUTTON_STYLES.join(", "),
                  )
                end

                if icon.length > MAX_ICON_LENGTH
                  errors << I18n.t(
                    "discourse_workflows.errors.chat_approval.button_icon_too_long",
                    position: position,
                    max: MAX_ICON_LENGTH,
                  )
                end
              end

              errors
            end
          end

          def execute(exec_ctx)
            message_text = exec_ctx.get_node_parameter("message", 0)
            buttons_value = exec_ctx.get_node_parameter("buttons", 0)
            buttons = self.class.button_rows("buttons" => buttons_value)
            validate_buttons!(buttons)

            channel_id = exec_ctx.get_node_parameter("channel_id", 0).to_i
            timeout_minutes = exec_ctx.get_node_parameter("timeout_minutes", 0).presence&.to_i
            if timeout_minutes && timeout_minutes < 1
              raise_node_error!(
                I18n.t("discourse_workflows.errors.chat_approval.timeout_must_be_positive"),
              )
            end

            timeout_action =
              exec_ctx.get_node_parameter("timeout_action", 0, default: "continue").to_s
            if TIMEOUT_ACTIONS.exclude?(timeout_action)
              raise_node_error!(
                I18n.t(
                  "discourse_workflows.errors.chat_approval.invalid_timeout_action",
                  action: timeout_action,
                ),
              )
            end

            blocks = [
              {
                "type" => "actions",
                "elements" =>
                  buttons.map.with_index do |button, index|
                    block =
                      button_block(
                        button["label"].to_s,
                        exec_ctx.resume_action_id(ACTION_IDS[index]),
                        button["value"].to_s,
                      )
                    block["style"] = button["style"].to_s if button["style"].present?
                    block["icon"] = button["icon"].to_s if button["icon"].present?
                    block
                  end,
              },
            ]
            send_chat_message(channel_id, message_text, blocks)

            exec_ctx.put_execution_to_wait(
              timeout_minutes&.minutes&.from_now,
              timeout_action: timeout_minutes ? timeout_action : nil,
            )
            [exec_ctx.input_items]
          end

          private

          def validate_buttons!(buttons)
            error = self.class.button_validation_errors(buttons).first
            raise_node_error!(error) if error
          end
        end
      end
    end
  end
end
