# frozen_string_literal: true

module DiscourseWorkflows
  class ExpressionResolver
    WHOLE_EXPRESSION_REGEX = /\A\{\{\s*([^{}]*?)\s*\}\}\z/

    def self.find_matching_close(template, start)
      depth = 1
      cursor = start

      while cursor < template.length - 1 && depth > 0
        if template[cursor] == "{" && template[cursor + 1] == "{"
          depth += 1
          cursor += 2
        elsif template[cursor] == "}" && template[cursor + 1] == "}"
          depth -= 1
          return cursor if depth == 0
          cursor += 2
        else
          cursor += 1
        end
      end

      nil
    end

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

    def evaluate_expression(expression)
      result = js_evaluator.evaluate(expression)
      last_error = js_evaluator.expression_errors.last

      if last_error && last_error[:expression] == expression
        { result: nil, error: last_error[:error], error_type: last_error[:type] }
      else
        { result:, error: nil, error_type: nil }
      end
    end

    def resolve_segments(template)
      segments = []
      pos = 0

      while pos < template.length
        open = template.index("{{", pos)

        if open.nil?
          segments << { kind: "plaintext", text: template[pos..] } if pos < template.length
          break
        end

        segments << { kind: "plaintext", text: template[pos...open] } if open > pos

        close = self.class.find_matching_close(template, open + 2)

        unless close
          segments << { kind: "plaintext", text: template[open..] }
          break
        end

        expression = template[(open + 2)...close].strip
        segment = { kind: "resolved", from: open, to: close + 2 }

        if expression.empty?
          segment.merge!(text: "", state: "empty")
        else
          segment.merge!(classify_eval_result(evaluate_expression(expression)))
        end

        segments << segment
        pos = close + 2
      end

      segments
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

    def classify_eval_result(eval_result)
      if eval_result[:error]
        state = eval_result[:error_type] == :undefined ? "undefined" : "invalid"
        return { text: "", state: }
      end

      result = eval_result[:result]
      return { text: "", state: "undefined" } if result.nil?
      return { text: "", state: "warning" } if result.is_a?(MiniRacer::JavaScriptFunction)

      { text: format_value(result), state: "valid" }
    end

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
      result = +""
      pos = 0

      while pos < template.length
        open = template.index("{{", pos)

        if open.nil?
          result << template[pos..]
          break
        end

        result << template[pos...open] if open > pos

        close = find_matching_close(template, open + 2)

        if close
          expression = template[(open + 2)...close].strip
          result << format_value(js_evaluator.evaluate(expression))
          pos = close + 2
        else
          result << template[open..]
          break
        end
      end

      result
    end

    def find_matching_close(template, start)
      self.class.find_matching_close(template, start)
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
        # Bare objects like { a: 1 } fail as blocks — retry wrapped in parens
        if e.message.include?("SyntaxError") && expression.strip.start_with?("{")
          begin
            return @sandbox.eval("(#{expression})")
          rescue MiniRacer::Error
          end
        end
        @expression_errors << { expression: expression, error: e.message, type: classify_error(e) }
        nil
      end

      def classify_error(error)
        msg = error.message
        if msg.include?("is not defined") || msg.include?("Cannot read properties")
          :undefined
        else
          :invalid
        end
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
          "$execution" => @context.fetch("__execution") { {} },
          "__node_contexts" => @context.fetch("__node_contexts") { {} },
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
              context: __data.__node_contexts[name] || {}
            };
          }
        JS
      end
    end
  end
end
