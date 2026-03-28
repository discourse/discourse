# frozen_string_literal: true

module DiscourseWorkflows
  module Core
    module Wait
      class V1 < Core::Base
        WAIT_UNITS = %w[seconds minutes hours days].freeze

        def self.identifier
          "core:wait"
        end

        def self.icon
          "clock"
        end

        def self.color_key
          "brown"
        end

        def self.output_schema
          WebhookSchema::OUTPUT_FIELDS.transform_values do |type|
            { type: type, visible_if: { resume: "webhook" } }
          end
        end

        def self.branching?
          false
        end

        def self.outputs
          %w[main]
        end

        def self.configuration_schema
          webhook_fields =
            WebhookSchema::CONFIGURATION_FIELDS.transform_values do |field|
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

        def execute(context, input_items:, node_context:, user: nil)
          resume_mode = @configuration["resume"]

          if resume_mode == "webhook"
            raise WaitForResume.new(
                    type: :webhook,
                    http_method: @configuration["http_method"] || "GET",
                    response_mode: @configuration["response_mode"] || "immediately",
                    response_code: @configuration["response_code"] || "200",
                  )
          else
            amount = (@configuration["wait_amount"] || 1).to_i
            unit = @configuration["wait_unit"] || "hours"
            raise WaitForResume.new(type: :timer, wait_amount: amount, wait_unit: unit)
          end
        end
      end
    end
  end
end
