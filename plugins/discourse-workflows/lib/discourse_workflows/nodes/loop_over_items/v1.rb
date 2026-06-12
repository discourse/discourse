# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module LoopOverItems
      class V1 < NodeType
        description(
          name: "flow:loop_over_items",
          version: "1.0",
          defaults: {
            icon: "arrow-rotate-right",
            color: "brown",
          },
          palette_visible: false,
          inputs: [{ key: "main", type: "main", required: true, multiple: true }],
          outputs: [
            { key: "done", label_key: "discourse_workflows.branch.done" },
            { key: "loop", label_key: "discourse_workflows.branch.loop" },
          ],
          properties: {
            batch_size: {
              type: :integer,
              required: true,
              default: 1,
              min: 1,
            },
          },
        )

        def execute(exec_ctx)
          batch_size = exec_ctx.get_node_parameter("batch_size", 0, default: 1).to_i
          batch_size = 1 if batch_size < 1

          if exec_ctx.get_context(:node)["items"].nil?
            execute_first(exec_ctx, batch_size)
          else
            execute_subsequent(exec_ctx, batch_size)
          end
        end

        private

        def execute_first(exec_ctx, batch_size)
          node_context = exec_ctx.get_context(:node)
          all_items = exec_ctx.input_items.dup
          node_context["current_run_index"] = 0
          node_context["max_run_index"] = (all_items.length.to_f / batch_size).ceil
          node_context["processed_items"] = []

          batch = all_items.shift(batch_size)
          node_context["items"] = all_items
          node_context["no_items_left"] = false
          node_context["done"] = false

          [[], batch]
        end

        def execute_subsequent(exec_ctx, batch_size)
          node_context = exec_ctx.get_context(:node)
          node_context["processed_items"].concat(exec_ctx.input_items)
          node_context["current_run_index"] += 1

          remaining = node_context["items"]
          batch = remaining.shift(batch_size)

          if batch.empty?
            node_context["done"] = true
            node_context["no_items_left"] = true
            [node_context["processed_items"], []]
          else
            [[], batch]
          end
        end
      end
    end
  end
end
