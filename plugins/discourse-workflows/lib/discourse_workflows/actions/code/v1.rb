# frozen_string_literal: true

module DiscourseWorkflows
  module Actions
    module Code
      class V1 < Actions::Base
        MAX_LOG_ENTRIES = 100

        def self.identifier
          "action:code"
        end

        def self.icon
          "code"
        end

        def self.color_key
          "red"
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

        def execute(context, input_items:, node_context:, user: nil)
          code = @configuration["code"].to_s
          @logs = []
          all_items_json = input_items.map { |item| item["json"] || {} }
          vars = DiscourseWorkflows::Variable.pluck(:key, :value).to_h

          input_items.map do |item|
            item_json = item["json"] || {}
            result = execute_code(context, item_json, all_items_json, code, vars, user)
            { "json" => result }
          end
        end

        private

        def execute_code(context, item_json, all_items_json, code, vars, user)
          sandbox = JsSandbox.new(context, user: user, vars: vars)
          begin
            sandbox.attach(
              "__captureLog",
              proc { |*args| @logs << args.map(&:to_s).join(" ") if @logs.size < MAX_LOG_ENTRIES },
            )

            item_json_js = item_json.to_json
            sandbox.eval(<<~JS)
              var $json = #{item_json_js};
              var $input = {
                item: { json: #{item_json_js} },
                all: function() { return #{all_items_json.to_json}.map(function(j) { return { json: j }; }); }
              };
              var console = {
                log: function() { __captureLog(...arguments); },
                warn: function() { __captureLog(...arguments); },
                error: function() { __captureLog(...arguments); },
                info: function() { __captureLog(...arguments); }
              };
            JS
            raw = sandbox.eval("(function() { #{code} })()")

            result = raw.is_a?(Hash) ? raw : { "result" => raw.to_s }
            result.deep_stringify_keys
          ensure
            sandbox.dispose
          end
        end
      end
    end
  end
end
