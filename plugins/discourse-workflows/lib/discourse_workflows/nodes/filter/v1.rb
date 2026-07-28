# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Filter
      class V1 < NodeType
        description(
          name: "condition:filter",
          version: "1.0",
          defaults: {
            icon: "filter",
            color: "violet",
          },
          outputs: [
            { key: "true", label_key: "discourse_workflows.executions.statuses.kept" },
            { key: "false", label_key: "discourse_workflows.executions.statuses.rejected" },
          ],
          capabilities: {
            run_scope: "per_item",
          },
          output_contracts: [{ mode: :passthrough }, { mode: :passthrough }],
          properties: {
            combinator: {
              type: :options,
              options: %w[and or],
              default: "and",
              no_data_expression: true,
            },
            conditions: {
              type: :array,
              ui: {
                control: :condition_builder,
              },
            },
            options: {
              type: :object,
              ui: {
                hidden: true,
              },
            },
          },
        )

        def execute(exec_ctx)
          exec_ctx
            .input_items
            .each_with_index
            .partition { |_item, item_index| exec_ctx.get_node_parameter(:conditions, item_index) }
            .map { |items| items.map(&:first) }
        end
      end
    end
  end
end
