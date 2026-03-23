# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module Code
      class V1 < Actions::Base
        TIMEOUT_MS = 1_000
        MAX_MEMORY = 10 * 1024 * 1024

        def self.identifier
          "action:code"
        end

        def self.configuration_schema
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

        attr_reader :logs

        def execute(context, input_items:, node_context:)
          code = @configuration["code"].to_s
          @logs = []
          all_items_json = input_items.map { |item| item["json"] || {} }
          vars = DiscourseWorkflows::Variable.pluck(:key, :value).to_h

          input_items.map do |item|
            item_json = item["json"] || {}
            result = execute_code(context, item_json, all_items_json, code, vars)
            { "json" => result }
          end
        end

        private

        def execute_code(context, item_json, all_items_json, code, vars)
          ctx = MiniRacer::Context.new(max_memory: MAX_MEMORY, timeout: TIMEOUT_MS)
          begin
            ctx.attach("__captureLog", proc { |*args| @logs << args.map(&:to_s).join(" ") })
            ctx.attach("__getSiteSetting", proc { |name| SiteSetting.get(name).to_s })
            ctx.attach(
              "__getNodeOutput",
              proc do |name|
                node_items = context[name]
                if node_items.is_a?(Array) && node_items.first.is_a?(Hash) &&
                     node_items.first.key?("json")
                  node_items.first["json"].to_json
                else
                  (node_items || {}).to_json
                end
              end,
            )

            item_json_js = item_json.to_json
            ctx.eval(<<~JS)
              var $json = #{item_json_js};
              var $vars = #{vars.to_json};
              var $input = {
                item: { json: #{item_json_js} },
                all: function() { return #{all_items_json.to_json}.map(function(j) { return { json: j }; }); }
              };
              var $site_settings = new Proxy({}, { get: function(_, name) { return __getSiteSetting(name); } });
              function $(nodeName) { var data = JSON.parse(__getNodeOutput(nodeName)); return { item: { json: data } }; }
              var console = {
                log: function() { __captureLog(...arguments); },
                warn: function() { __captureLog(...arguments); },
                error: function() { __captureLog(...arguments); },
                info: function() { __captureLog(...arguments); }
              };
            JS
            raw = ctx.eval("(function() { #{code} })()")

            result = raw.is_a?(Hash) ? raw : { "result" => raw.to_s }
            result.deep_stringify_keys
          ensure
            ctx.dispose
          end
        end
      end
    end
  end
end
