# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Merge
      class V1 < NodeType
        description(
          name: "flow:merge",
          version: "1.0",
          defaults: {
            icon: "arrows-turn-to-dots",
            color: "blue",
          },
          capabilities: {
            run_scope: "all_items",
          },
          inputs: [
            { key: "main", type: "main", display_name: "Input", required: false, multiple: true },
          ],
          required_inputs: 1,
        )

        def execute(exec_ctx)
          [append_inputs(exec_ctx)]
        end

        private

        def append_inputs(exec_ctx)
          exec_ctx.inputs.flatten(1)
        end
      end
    end
  end
end
