# frozen_string_literal: true

module DiscourseWorkflows
  class ExpressionResolver
    EXPRESSION_REGEX = /\{\{(.*?)\}\}/
    WHOLE_EXPRESSION_REGEX = /\A\{\{\s*([^{}]*?)\s*\}\}\z/

    def self.resolve(value, context: {}, user: nil)
      resolver = new(context, user: user)
      resolver.resolve(value)
    ensure
      resolver&.dispose
    end

    def self.resolve_hash(hash, context: {}, user: nil)
      resolver = new(context, user: user)
      resolver.resolve_hash(hash)
    ensure
      resolver&.dispose
    end

    def initialize(context, user: nil, sandbox: nil, **_)
      @context = context
      @user = user
      @shared_sandbox = sandbox
    end

    def resolve(value)
      return value unless resolvable_string?(value)

      expression_body = value[1..].strip
      whole_expression = expression_body.match(WHOLE_EXPRESSION_REGEX)&.captures&.first

      whole_expression ? js_evaluator.evaluate(whole_expression) : render_template(expression_body)
    end

    def resolve_hash(hash)
      resolve_tree(hash)
    end

    def dispose
      @js_evaluator&.dispose
      @js_evaluator = nil
    end

    def expression_errors
      @js_evaluator&.expression_errors || []
    end

    def with_item(item_json)
      previous_json = @context["$json"]
      @context["$json"] = item_json
      js_evaluator.rebind_json(item_json)
      yield
    ensure
      @context["$json"] = previous_json
      js_evaluator.rebind_json(previous_json || {})
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
      @js_evaluator ||= JsEvaluator.new(@context, user: @user, sandbox: @shared_sandbox)
    end

    def format_value(value)
      return "" if value.nil?
      Array(value).join(", ")
    end

    class JsEvaluator
      def initialize(context, user: nil, sandbox: nil)
        @context = context
        @user = user
        @shared_sandbox = sandbox
        @sandbox = nil
        @owned = false
        @expression_errors = []
      end

      attr_reader :expression_errors

      def evaluate(expression)
        ensure_sandbox!
        @sandbox.eval(expression)
      rescue MiniRacer::Error => e
        @expression_errors << { expression: expression, error: e.message }
        nil
      end

      def dispose
        @sandbox&.dispose if @owned
        @sandbox = nil
      end

      def rebind_json(new_json)
        ensure_sandbox!
        @sandbox.rebind_json(new_json)
      end

      private

      def ensure_sandbox!
        return if @sandbox
        if @shared_sandbox
          @sandbox = @shared_sandbox
        else
          @sandbox = JsSandbox.new(@context, user: @user)
          @owned = true
        end
        inject_expression_data!
      end

      def inject_expression_data!
        data = build_expression_data
        @sandbox.attach("__fetchExprNode", method(:fetch_node_for_expression))
        @sandbox.eval("var __data = #{data.to_json};")
        @sandbox.eval(expression_setup_js)
      end

      def build_expression_data
        {
          "$json" => @context.fetch("$json") { {} },
          "trigger" => @context.fetch("trigger") { {} },
          "$execution" => @context.fetch("_execution") { {} },
          "_node_contexts" => @context.fetch("_node_contexts") { {} },
        }
      end

      def fetch_node_for_expression(name)
        return {}.to_json if name.to_s.start_with?("_")
        JsSandbox.extract_item_json(@context[name]).to_json
      end

      def expression_setup_js
        <<~JS
          var $json = __data["$json"];
          var trigger = __data["trigger"];
          var $execution = __data["$execution"];
          var __nodeCache = {};
          function $(name) {
            if (!(name in __nodeCache)) {
              __nodeCache[name] = JSON.parse(__fetchExprNode(name));
            }
            return {
              item: { json: __nodeCache[name] },
              context: __data._node_contexts[name] || {}
            };
          }
        JS
      end
    end
  end
end
