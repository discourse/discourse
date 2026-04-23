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
          //   $("NodeName")          - access another node's output
          //   $vars.KEY              - workflow variables
          //   $site_settings.NAME    - site settings
          //   $execution             - execution metadata (id, workflow_name, ...)
          //   $current_user          - user running the workflow
          //   console.log/warn/error - logging

          // Example: add a new field called 'foo' to the current item
          $input.item.json.foo = 1;

          return $input.item;
        JS

        def self.identifier
          "action:code"
        end

        def self.icon
          "code"
        end

        def self.color
          "red"
        end

        def self.property_schema
          {
            mode: {
              type: :options,
              default: "run_once_for_each_item",
              options: %w[run_once_for_each_item run_once_for_all_items],
              ui: {
                expression: false,
              },
            },
            code: {
              type: :string,
              required: true,
              default: DEFAULT_CODE,
              ui: {
                control: :code,
                expression: false,
              },
              control_options: {
                height: 300,
                lang: :javascript,
              },
            },
            output_fields: {
              type: :array,
              required: false,
              ui: {
                hidden: true,
              },
            },
          }
        end

        def execute(exec_ctx)
          code = @configuration["code"].to_s
          mode = @configuration["mode"] || "run_once_for_each_item"

          items =
            exec_ctx.with_sandbox(capture_logs: true) do |sandbox|
              setup_code_sandbox!(
                sandbox,
                exec_ctx.input_items,
                @configuration,
                DiscourseWorkflows::InputContext.from_node_context(exec_ctx.node_context),
              )
              if mode == "run_once_for_all_items"
                execute_all_items(sandbox, code)
              else
                execute_per_item(sandbox, code, exec_ctx.input_items)
              end
            end
          [items]
        end

        private

        def execute_per_item(sandbox, code, input_items)
          input_items.each_with_index.map do |item, item_index|
            sandbox.rebind_code_item(item, item_index:)
            raw = sandbox.eval("(function() { #{code} })()")
            wrap(normalize_code_result(raw))
          end
        end

        def execute_all_items(sandbox, code)
          raw = sandbox.eval("(function() { #{code} })()")
          results = raw.is_a?(Array) ? raw : [raw]
          results.map { |r| wrap(normalize_code_result(r)) }
        end

        def normalize_code_result(raw)
          result = raw.is_a?(Hash) ? raw : { "result" => raw.to_s }
          result.deep_stringify_keys
        end

        def setup_code_sandbox!(sandbox, input_items, input_params, input_context)
          sandbox.declare_json("__allInputItems", input_items)
          sandbox.declare_json("__inputParams", input_params)
          sandbox.declare_json("__inputContext", input_context)
          sandbox.eval(<<~JS)
            function __WorkflowCodeInput(item) {
              this.item = item;
              this.params = __inputParams;
              this.context = __inputContext;
            }

            __WorkflowCodeInput.prototype.all = function() {
              return __allInputItems;
            };

            __WorkflowCodeInput.prototype.first = function() {
              return __allInputItems[0] || { json: {} };
            };

            __WorkflowCodeInput.prototype.last = function() {
              return __allInputItems[__allInputItems.length - 1] || { json: {} };
            };

            var $input = new __WorkflowCodeInput({ json: {} });
            var __itemIndex = 0;
            Object.defineProperty(this, '$json', {
              get: function() { return $input.item.json; },
              set: function(value) { $input.item.json = value; },
              configurable: true
            });
            Object.defineProperty(this, '$itemIndex', {
              get: function() { return __itemIndex; },
              set: function(value) { __itemIndex = value; },
              configurable: true
            });
          JS
        end
      end
    end
  end
end
