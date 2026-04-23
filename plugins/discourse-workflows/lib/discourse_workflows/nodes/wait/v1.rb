# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Wait
      class V1 < NodeType
        WAIT_UNITS = %w[seconds minutes hours days].freeze

        def self.identifier
          "flow:wait"
        end

        def self.icon
          "pause"
        end

        def self.color
          "salmon"
        end

        def self.waits_for_resume?
          true
        end

        def self.output_schema
          Schemas::Webhook::OUTPUT_FIELDS.transform_values do |type|
            { type: type, visible_if: { resume: "webhook" } }
          end
        end

        def self.outputs
          %w[main]
        end

        def self.property_schema
          webhook_fields =
            Schemas::Webhook::CONFIGURATION_FIELDS.transform_values do |field|
              visible_if = (field[:visible_if] || {}).merge(resume: "webhook")
              field.merge(visible_if: visible_if)
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
              visible_if: {
                resume: "time_interval",
              },
            },
            wait_unit: {
              type: :options,
              required: true,
              default: "hours",
              options: WAIT_UNITS,
              visible_if: {
                resume: "time_interval",
              },
            },
            webhook_info: {
              type: :notice,
              visible_if: {
                resume: "webhook",
              },
            },
            **webhook_fields,
            webhook_suffix:
              Schemas::Webhook::WEBHOOK_SUFFIX_FIELD.merge(visible_if: { resume: "webhook" }),
            limit_wait_time: {
              type: :boolean,
              default: false,
              visible_if: {
                resume: "webhook",
              },
            },
            timeout_amount: {
              type: :integer,
              required: false,
              visible_if: {
                resume: "webhook",
                limit_wait_time: true,
              },
            },
            timeout_unit: {
              type: :options,
              required: false,
              default: "hours",
              options: WAIT_UNITS,
              visible_if: {
                resume: "webhook",
                limit_wait_time: true,
              },
            },
          }
        end

        def execute(exec_ctx)
          resume_mode = @configuration.fetch("resume")

          if resume_mode == "webhook"
            waiting_until = webhook_waiting_until
          else
            amount = @configuration.fetch("wait_amount") { 1 }.to_i
            unit = @configuration.fetch("wait_unit") { "hours" }

            raise ArgumentError, "Wait amount must be greater than 0" if amount <= 0
            raise ArgumentError, "Invalid wait unit: #{unit}" if WAIT_UNITS.exclude?(unit)

            waiting_until = amount.public_send(unit).from_now
          end

          exec_ctx.put_execution_to_wait(waiting_until)
          [exec_ctx.input_items]
        end

        private

        def webhook_waiting_until
          return nil unless @configuration["limit_wait_time"]

          timeout_amount = @configuration["timeout_amount"].presence&.to_i
          timeout_unit = @configuration["timeout_unit"].presence || "hours"

          if WAIT_UNITS.exclude?(timeout_unit)
            raise ArgumentError, "Invalid timeout unit: #{timeout_unit}"
          end
          if timeout_amount && timeout_amount <= 0
            raise ArgumentError, "Timeout amount must be greater than 0"
          end

          timeout_amount&.public_send(timeout_unit)&.from_now
        end
      end
    end
  end
end
