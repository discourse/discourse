# frozen_string_literal: true

module DiscourseWorkflows
  class ExpressionResolver
    EXPRESSION_REGEX = /\{\{(.*?)\}\}/
    WHOLE_EXPRESSION_REGEX = /\A\{\{\s*([^{}]*?)\s*\}\}\z/

    def initialize(context, user: nil, **_)
      @context = context
      @user = user
    end

    def resolve(value)
      return value unless resolvable_string?(value)

      template = value[1..].strip
      expression = template.match(WHOLE_EXPRESSION_REGEX)&.captures&.first

      return js_evaluator.evaluate(expression) if expression

      render_template(template)
    end

    def resolve_hash(hash)
      resolve_tree(hash)
    end

    private

    def resolve_tree(value)
      case value
      when Hash
        value.transform_values { |nested_value| resolve_tree(nested_value) }
      when Array
        value.map { |item| resolve_tree(item) }
      else
        resolve(value)
      end
    end

    def resolvable_string?(value)
      value.is_a?(String) && value.start_with?("=")
    end

    def render_template(template)
      template.gsub(EXPRESSION_REGEX) do
        expression = Regexp.last_match(1).strip
        format_value(js_evaluator.evaluate(expression))
      end
    end

    def js_evaluator
      @js_evaluator ||= JsEvaluator.new(@context, user: @user)
    end

    def format_value(value)
      return "" if value.nil?
      value.is_a?(Array) ? value.join(", ") : value.to_s
    end

    class JsEvaluator
      def initialize(context, user: nil)
        @context = context
        @user = user
        @sandbox = nil
      end

      def evaluate(expression)
        ensure_sandbox!
        @sandbox.eval(expression)
      rescue MiniRacer::Error
        nil
      end

      private

      def ensure_sandbox!
        return if @sandbox

        @sandbox = JsSandbox.new(@context, user: @user)
        inject_expression_data!
      end

      def inject_expression_data!
        data = build_expression_data
        @sandbox.eval("var __data = #{data.to_json};")
        @sandbox.eval(expression_setup_js)
      end

      def build_expression_data
        node_outputs = {}
        node_contexts = @context["_node_contexts"] || {}

        @context.each do |key, value|
          next if key.start_with?("_") || key == "$json"
          node_outputs[key] = JsSandbox.extract_item_json(value)
        end

        {
          "$json" => @context["$json"] || {},
          "trigger" => @context["trigger"] || {},
          "$execution" => @context["_execution"] || {},
          "_nodes" => node_outputs,
          "_node_contexts" => node_contexts,
        }
      end

      def expression_setup_js
        <<~JS
          var $json = __data["$json"];
          var trigger = __data["trigger"];
          var $execution = __data["$execution"];
          function $(name) {
            return {
              item: { json: __data._nodes[name] || {} },
              context: __data._node_contexts[name] || {}
            };
          }
        JS
      end
    end
  end
end
