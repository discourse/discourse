# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module Code
      class V1 < NodeType
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
            code: {
              type: :string,
              required: true,
              ui: {
                control: :code,
                expression: false,
                height: 300,
                lang: :javascript,
              },
            },
            output_fields: {
              type: :collection,
              required: false,
              item_schema: {
                key: {
                  type: :string,
                  required: true,
                  ui: {
                    expression: false,
                  },
                },
                type: {
                  type: :options,
                  required: true,
                  options: %w[string integer array boolean],
                  default: "string",
                },
              },
            },
          }
        end

        def self.output_schema
          { result: :string }
        end

        def execute(exec_ctx)
          code = @configuration["code"].to_s
          all_items_json = exec_ctx.input_items.map { |item| item.fetch("json") { {} } }

          items =
            exec_ctx.with_sandbox(capture_logs: true) do |sandbox|
              setup_code_sandbox!(sandbox, all_items_json)
              exec_ctx.input_items.map do |item|
                item_json = item.fetch("json") { {} }
                sandbox.rebind_code_item(item_json)
                raw = sandbox.eval("(function() { #{code} })()")
                Item.new(normalize_code_result(raw)).to_h
              end
            end
          [items]
        end

        private

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
