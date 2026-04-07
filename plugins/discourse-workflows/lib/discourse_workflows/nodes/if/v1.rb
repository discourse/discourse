# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module If
      class V1 < NodeType
        def self.identifier
          "condition:if"
        end

        def self.icon
          "arrows-split-up-and-left"
        end

        def self.color_key
          "blue"
        end

        def self.outputs
          [
            { key: "true", label_key: "discourse_workflows.branch.true" },
            { key: "false", label_key: "discourse_workflows.branch.false" },
          ]
        end

        def self.configuration_schema
          {
            combinator: {
              type: :options,
              options: %w[and or],
              default: "and",
              ui: {
                expression: false,
              },
            },
            conditions: {
              type: :array,
              ui: {
                control: :condition_builder,
              },
            },
            options: {
              caseSensitive: :boolean,
              typeValidation: :string,
              ui: {
                hidden: true,
              },
            },
          }
        end

        def execute(exec_ctx)
          exec_ctx.input_items.partition do |item|
            exec_ctx.with_item(item) { exec_ctx.evaluate_filter(@configuration) }
          end
        end
      end
    end
  end
end
