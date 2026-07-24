# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Code
      class V1 < NodeType
        DEFAULT_CODE = <<~JS
          // Available variables:
          //   $input.item.json       - current item's JSON data
          //   $input.all()           - array of all input items
          //   $json                  - shortcut for $input.item.json
          //   $("NodeName").item     - access the paired item from another node
          //   $vars.KEY              - workflow variables
          //   $site_settings.NAME    - site settings
          //   $execution             - execution metadata (id, workflow_name, ...)
          //   $current_user          - user running the workflow
          //   console.log/warn/error - logging

          // Example: add a new field called 'foo' to every input item
          var items = $input.all();
          items.forEach(function(item) {
            item.json.foo = 1;
          });

          return items;
        JS
        RUN_ONCE_FOR_ALL_ITEMS = "runOnceForAllItems"
        RUN_ONCE_FOR_EACH_ITEM = "runOnceForEachItem"

        description(
          name: "action:code",
          version: "1.0",
          defaults: {
            icon: "code",
            color: "red",
          },
          capabilities: {
            run_scope: {
              parameter: "mode",
              values: {
                RUN_ONCE_FOR_EACH_ITEM => "per_item",
                RUN_ONCE_FOR_ALL_ITEMS => "all_items",
              },
            },
          },
          properties: {
            mode: {
              type: :options,
              default: RUN_ONCE_FOR_ALL_ITEMS,
              options: [RUN_ONCE_FOR_EACH_ITEM, RUN_ONCE_FOR_ALL_ITEMS],
              no_data_expression: true,
            },
            code: {
              type: :string,
              required: true,
              default: DEFAULT_CODE,
              no_data_expression: true,
              ui: {
                control: :code,
              },
              control_options: {
                height: 300,
                lang: :javascript,
              },
            },
          },
        )

        def execute(exec_ctx)
          code =
            exec_ctx.get_node_parameter(
              "code",
              0,
              default: DEFAULT_CODE,
              options: {
                raw_expressions: true,
              },
            ).to_s
          mode = exec_ctx.get_node_parameter("mode", 0, default: RUN_ONCE_FOR_ALL_ITEMS)
          validate_mode!(mode)

          sandbox = JsTaskRunnerSandbox.new(exec_ctx.get_mode, exec_ctx)
          [
            if mode == RUN_ONCE_FOR_ALL_ITEMS
              sandbox.run_code_all_items(code)
            else
              sandbox.run_code_for_each_item(code, exec_ctx.get_input_data.length)
            end,
          ]
        end

        private

        def validate_mode!(mode)
          return if [RUN_ONCE_FOR_ALL_ITEMS, RUN_ONCE_FOR_EACH_ITEM].include?(mode)

          raise_node_error!(
            "Invalid Code mode",
            description: "#{mode.inspect} is not a supported Code execution mode.",
          )
        end
      end
    end
  end
end
