# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Modal
      class V1 < NodeType
        USER_CHANNEL_PREFIX = "/discourse-workflows/user-modal"
        BUTTON_STYLES = %w[default primary danger].freeze
        DEFAULT_BUTTON_STYLE = "default"

        description(
          name: "action:modal",
          version: "1.0",
          defaults: {
            icon: "window-maximize",
            color: "blue",
          },
          group: "human_review",
          properties: {
            target_user: {
              type: :string,
              required: false,
            },
            title: {
              type: :string,
              required: true,
            },
            body: {
              type: :string,
              ui: {
                control: :textarea,
              },
            },
            buttons: {
              type: :fixed_collection,
              type_options: {
                multiple_values: true,
              },
              options: [
                {
                  name: "values",
                  values: {
                    label: {
                      type: :string,
                      required: true,
                      ui: {
                        expression: false,
                      },
                    },
                    value: {
                      type: :string,
                      required: true,
                      ui: {
                        expression: false,
                      },
                    },
                    style: {
                      type: :options,
                      default: DEFAULT_BUTTON_STYLE,
                      options: BUTTON_STYLES,
                      ui: {
                        expression: false,
                      },
                    },
                  },
                },
              ],
            },
          },
          capabilities: {
            waits_for_resume: true,
          },
        )

        def self.user_channel(user_id)
          "#{USER_CHANNEL_PREFIX}/#{user_id}"
        end

        def self.button_rows(parameters)
          DiscourseWorkflows::CollectionParameters.rows_from_value(
            DiscourseWorkflows::CollectionParameters.fetch_value(parameters, :buttons),
          )
        end

        def self.button_values(parameters)
          button_rows(parameters).filter_map { |row| row["value"].to_s.presence }
        end

        def self.response_items(action:)
          [{ "json" => { "button" => action.to_s }, "pairedItem" => { "item" => 0 } }]
        end

        def execute(exec_ctx)
          target_user = resolve_target_user(exec_ctx)
          buttons = build_buttons(exec_ctx, target_user)

          MessageBus.publish(
            self.class.user_channel(target_user.id),
            {
              type: "show_modal",
              title: exec_ctx.get_node_parameter("title", 0).to_s,
              body: exec_ctx.get_node_parameter("body", 0).to_s,
              buttons: buttons,
            },
            user_ids: [target_user.id],
          )

          # With buttons we pause until the user picks one. With no buttons there
          # is nothing to respond to, so the modal is informational: show it and
          # let the flow continue (the user just closes it).
          exec_ctx.put_execution_to_wait(nil) if buttons.any?
          [exec_ctx.input_items]
        end

        private

        def resolve_target_user(exec_ctx)
          username = exec_ctx.get_node_parameter("target_user", 0).presence

          if username
            user = ::User.find_by(username: username)
            if user.nil?
              raise_node_error!(
                I18n.t("discourse_workflows.errors.modal.user_not_found", username: username),
              )
            end
            return user
          end

          user = exec_ctx.user
          raise_node_error!(I18n.t("discourse_workflows.errors.modal.no_target_user")) if user.nil?
          user
        end

        def build_buttons(exec_ctx, target_user)
          rows =
            DiscourseWorkflows::CollectionParameters.rows_from_value(
              exec_ctx.get_node_parameter("buttons", 0, default: []),
            )

          rows.filter_map do |row|
            value = row["value"].to_s
            next if value.blank?

            {
              "label" => row["label"].to_s.presence || value,
              "value" => value,
              "style" => normalize_style(row["style"]),
              "action_id" => exec_ctx.resume_action_id(value, target_user_id: target_user.id),
            }
          end
        end

        def normalize_style(style)
          BUTTON_STYLES.include?(style.to_s) ? style.to_s : DEFAULT_BUTTON_STYLE
        end
      end
    end
  end
end
