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
          all_items_json = exec_ctx.input_items.map { |item| item.fetch("json") { {} } }

          items =
            exec_ctx.with_sandbox(capture_logs: true) do |sandbox|
              setup_code_sandbox!(sandbox, all_items_json)
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
          input_items.map do |item|
            item_json = item.fetch("json") { {} }
            sandbox.rebind_code_item(item_json)
            raw = sandbox.eval("(function() { #{code} })()")
            Item.new(normalize_code_result(raw)).to_h
          end
        end

        def execute_all_items(sandbox, code)
          raw = sandbox.eval("(function() { #{code} })()")
          results = raw.is_a?(Array) ? raw : [raw]
          results.map { |r| Item.new(normalize_code_result(r)).to_h }
        end

        def normalize_code_result(raw)
          result = raw.is_a?(Hash) ? raw : { "result" => raw.to_s }
          result.deep_stringify_keys
        end

        def setup_code_sandbox!(sandbox, all_items_json)
          sandbox.eval(<<~JS)
            var $json = {};
            var $input = {
              item: { json: {} },
              all: function() { return #{all_items_json.to_json}.map(function(j) { return { json: j }; }); }
            };
          JS
        end
      end
    end
  end
end
