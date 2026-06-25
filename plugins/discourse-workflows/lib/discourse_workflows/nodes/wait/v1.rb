# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Wait
      class V1 < NodeType
        WAIT_UNITS = %w[seconds minutes hours days].freeze

        description(
          name: "flow:wait",
          version: "1.0",
          defaults: {
            icon: "pause",
            color: "salmon",
          },
          outputs: %w[main],
          properties:
            lambda do
              webhook_fields =
                Schemas::Webhook::CONFIGURATION_FIELDS.transform_values do |field|
                  display_options = field[:display_options] || {}
                  show = (display_options[:show] || {}).merge(resume: ["webhook"])
                  field.merge(display_options: display_options.merge(show: show))
                end

              {
                resume: {
                  type: :options,
                  required: true,
                  default: "time_interval",
                  options: %w[time_interval webhook],
                },
                wait_amount: {
                  type: :integer,
                  required: true,
                  default: 1,
                  display_options: {
                    show: {
                      resume: ["time_interval"],
                    },
                  },
                },
                wait_unit: {
                  type: :options,
                  required: true,
                  default: "hours",
                  options: WAIT_UNITS,
                  display_options: {
                    show: {
                      resume: ["time_interval"],
                    },
                  },
                },
                webhook_info: {
                  type: :notice,
                  display_options: {
                    show: {
                      resume: ["webhook"],
                    },
                  },
                },
                **webhook_fields,
                webhook_suffix:
                  Schemas::Webhook::WEBHOOK_SUFFIX_FIELD.merge(
                    display_options: {
                      show: {
                        resume: ["webhook"],
                      },
                    },
                  ),
                limit_wait_time: {
                  type: :boolean,
                  default: false,
                  display_options: {
                    show: {
                      resume: ["webhook"],
                    },
                  },
                },
                timeout_amount: {
                  type: :integer,
                  required: false,
                  display_options: {
                    show: {
                      resume: ["webhook"],
                      limit_wait_time: [true],
                    },
                  },
                },
                timeout_unit: {
                  type: :options,
                  required: false,
                  default: "hours",
                  options: WAIT_UNITS,
                  display_options: {
                    show: {
                      resume: ["webhook"],
                      limit_wait_time: [true],
                    },
                  },
                },
              }
            end,
          capabilities: {
            waits_for_resume: true,
            produces_data: false,
          },
        )

        def execute(exec_ctx)
          resume_mode = exec_ctx.get_node_parameter("resume", 0, default: "time_interval")

          if resume_mode == "webhook"
            waiting_until = webhook_waiting_until(exec_ctx)
          else
            amount = exec_ctx.get_node_parameter("wait_amount", 0, default: 1).to_i
            unit = exec_ctx.get_node_parameter("wait_unit", 0, default: "hours")

            if amount <= 0
              raise_node_error!(I18n.t("discourse_workflows.errors.wait.amount_must_be_positive"))
            end
            if WAIT_UNITS.exclude?(unit)
              raise_node_error!(I18n.t("discourse_workflows.errors.wait.invalid_unit", unit: unit))
            end

            waiting_until = amount.public_send(unit).from_now
          end

          exec_ctx.put_execution_to_wait(waiting_until)
          [exec_ctx.input_items]
        end

        private

        def webhook_waiting_until(exec_ctx)
          return nil unless exec_ctx.get_node_parameter("limit_wait_time", 0, default: false)

          timeout_amount = exec_ctx.get_node_parameter("timeout_amount", 0, default: nil).presence
          timeout_amount = timeout_amount.to_i if timeout_amount
          timeout_unit = exec_ctx.get_node_parameter("timeout_unit", 0, default: "hours").presence

          if WAIT_UNITS.exclude?(timeout_unit)
            raise_node_error!(
              I18n.t("discourse_workflows.errors.wait.invalid_timeout_unit", unit: timeout_unit),
            )
          end
          if timeout_amount && timeout_amount <= 0
            raise_node_error!(
              I18n.t("discourse_workflows.errors.wait.timeout_amount_must_be_positive"),
            )
          end

          timeout_amount&.public_send(timeout_unit)&.from_now
        end
      end
    end
  end
end
