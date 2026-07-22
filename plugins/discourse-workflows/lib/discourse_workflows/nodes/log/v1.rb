# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Log
      class V1 < NodeType
        RUN_ONCE_FOR_ALL_ITEMS = "runOnceForAllItems"
        RUN_ONCE_FOR_EACH_ITEM = "runOnceForEachItem"

        description(
          name: "action:log",
          version: "1.0",
          defaults: {
            icon: "scroll",
            color: "purple",
          },
          capabilities: {
            produces_data: false,
            run_scope: {
              parameter: "mode",
              values: {
                RUN_ONCE_FOR_EACH_ITEM => "per_item",
                RUN_ONCE_FOR_ALL_ITEMS => "all_items",
              },
            },
          },
          output_contracts: [{ mode: :passthrough }],
          properties: {
            mode: {
              type: :options,
              default: RUN_ONCE_FOR_EACH_ITEM,
              options: [RUN_ONCE_FOR_EACH_ITEM, RUN_ONCE_FOR_ALL_ITEMS],
              no_data_expression: true,
            },
            entries: {
              type: :fixed_collection,
              required: false,
              type_options: {
                multiple_values: true,
              },
              options: [
                {
                  name: "values",
                  values: {
                    key: {
                      type: :string,
                      required: true,
                      no_data_expression: true,
                    },
                    value: {
                      type: :string,
                      required: true,
                    },
                  },
                },
              ],
            },
          },
        )

        def execute(exec_ctx)
          mode = exec_ctx.get_node_parameter("mode", 0, default: RUN_ONCE_FOR_EACH_ITEM)

          if mode == RUN_ONCE_FOR_ALL_ITEMS || exec_ctx.input_items.empty?
            log_entries(exec_ctx, 0)
          else
            exec_ctx.input_items.each_with_index do |_item, item_index|
              log_entries(exec_ctx, item_index)
            end
          end

          [exec_ctx.input_items]
        end

        private

        def log_entries(exec_ctx, item_index)
          entries = exec_ctx.get_node_parameter("entries.values", item_index, default: [])
          entries.each { |entry| exec_ctx.log.kv(entry["key"].to_s, entry["value"].to_s) }
        end
      end
    end
  end
end
