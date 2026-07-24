# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Limit
      class V1 < NodeType
        description(
          name: "action:limit",
          version: "1.0",
          defaults: {
            icon: "magnifying-glass-minus",
            color: "yellow",
          },
          group: "flow",
          capabilities: {
            run_scope: "all_items",
          },
          output_contracts: [{ mode: :passthrough }],
          properties: {
            max_items: {
              type: :integer,
              required: false,
              default: 10,
              min: 1,
            },
            keep: {
              type: :options,
              required: false,
              options: %w[first last],
              default: "first",
            },
          },
        )

        def execute(exec_ctx)
          max = [exec_ctx.get_node_parameter("max_items", 0, default: 10).to_i, 1].max
          keep = exec_ctx.get_node_parameter("keep", 0, default: "first")

          [keep == "last" ? exec_ctx.input_items.last(max) : exec_ctx.input_items.first(max)]
        end
      end
    end
  end
end
