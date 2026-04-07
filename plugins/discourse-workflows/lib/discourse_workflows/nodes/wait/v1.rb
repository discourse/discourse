# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Wait
      class V1 < NodeType
        WAIT_UNITS = %w[seconds minutes hours days].freeze
        MAX_WAIT_DURATION_SECONDS = 30.days.to_i

        def self.identifier
          "core:wait"
        end

        def self.icon
          "pause"
        end

        def self.color_key
          "salmon"
        end

        def self.output_schema
          Schemas::Webhook::OUTPUT_FIELDS.transform_values do |type|
            { type: type, visible_if: { resume: "webhook" } }
          end
        end

        def self.outputs
          %w[main]
        end

        def self.configuration_schema
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
              type: :number,
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
          }
        end

        def execute(exec_ctx)
          resume_mode = @configuration.fetch("resume")

          if resume_mode == "webhook"
            raise WaitForWebhook.new(
                    http_method: @configuration.fetch("http_method") { "GET" },
                    response_mode: @configuration.fetch("response_mode") { "immediately" },
                    response_code: @configuration.fetch("response_code") { "200" },
                  )
          else
            amount = @configuration.fetch("wait_amount") { 1 }.to_i
            unit = @configuration.fetch("wait_unit") { "hours" }

            raise ArgumentError, "Invalid wait unit: #{unit}" if WAIT_UNITS.exclude?(unit)

            duration_seconds = [amount.public_send(unit).to_i, MAX_WAIT_DURATION_SECONDS].min

            raise WaitForTimer.new(
                    wait_amount: amount,
                    wait_unit: unit,
                    wait_duration_seconds: duration_seconds,
                  )
          end
        end
      end
    end
  end
end
