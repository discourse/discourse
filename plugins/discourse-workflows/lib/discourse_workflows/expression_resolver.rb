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
      with_owned_sandbox(context, user: user) { |resolver| resolver.resolve(value) }
    end

    def self.resolve_hash(hash, context: {}, user: nil)
      with_owned_sandbox(context, user: user) { |resolver| resolver.resolve_hash(hash) }
    end

    def self.resolve_segments(template, context: {}, user: nil)
      with_owned_sandbox(context, user: user) { |resolver| resolver.resolve_segments(template) }
    rescue MiniRacer::Error, JsSandbox::BudgetExceededError, JsSandbox::SandboxError => e
      Rails.logger.warn("Expression evaluation failed: #{e.message}")
      []
    end

    def self.with_owned_sandbox(context, user: nil)
      sandbox = JsSandbox.new(context, user: user)
      resolver = new(context, user: user, sandbox: sandbox)
      yield resolver
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    def initialize(context, sandbox:, user: nil, **_)
      @context = context
      @user = user
      @sandbox = sandbox
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

      scan_template(template) do |kind, content, from, to|
        if kind == :plaintext
          segments << { kind: "plaintext", text: content }
          next
        end

        segment = { kind: "resolved", from:, to: }

        if content.empty?
          segment.merge!(text: "", state: "empty")
        else
          segment.merge!(classify_eval_result(evaluate_expression(content)))
        end

        segments << segment
      end

      segments
    end

    def with_item(item, item_index: 0)
      input_item = normalize_input_item(item)
      previous_json = @context["$json"]
      previous_input_item = @context["__input_item"]
      previous_item_index = @context["$itemIndex"]

      @context["$json"] = input_item.fetch("json") { {} }
      @context["__input_item"] = input_item
      @context["$itemIndex"] = item_index
      @js_evaluator&.rebind_input_item(input_item, item_index:)
      yield
    ensure
      restore_context_value("$json", previous_json)
      restore_context_value("__input_item", previous_input_item)
      restore_context_value("$itemIndex", previous_item_index)
      @js_evaluator&.rebind_input_item(
        previous_input_item || { "json" => previous_json || {} },
        item_index: previous_item_index || 0,
      )
    end

    private

    def normalize_input_item(item)
      if item.is_a?(Hash)
        stringified_item = item.deep_stringify_keys
        return stringified_item if stringified_item.key?("json")
      end

      { "json" => item.deep_stringify_keys }
    end

    def restore_context_value(key, value)
      if value.nil?
        @context.delete(key)
      else
        @context[key] = value
      end
    end

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

      scan_template(template) do |kind, content, _from, _to|
        if kind == :expression
          result << format_value(js_evaluator.evaluate(content))
        else
          result << content
        end
      end

      result
    end

    def scan_template(template)
      pos = 0

      while pos < template.length
        open = template.index("{{", pos)

        if open.nil?
          yield :plaintext, template[pos..], pos, template.length if pos < template.length
          break
        end

        yield :plaintext, template[pos...open], pos, open if open > pos

        close = self.class.find_matching_close(template, open + 2)

        unless close
          yield :plaintext, template[open..], open, template.length
          break
        end

        yield :expression, template[(open + 2)...close].strip, open, close + 2
        pos = close + 2
      end
    end

    def js_evaluator
      @js_evaluator ||= JsEvaluator.new(@context, user: @user, sandbox: @sandbox)
    end

    def format_value(value)
      return "" if value.nil?
      Array(value).join(", ")
    end

    class JsEvaluator
      BLOCKED_NODE_NAMES = %w[constructor prototype eval].freeze

      def initialize(context, sandbox:, user: nil)
        @context = context
        @user = user
        @sandbox = sandbox
        @initialized = false
        @expression_errors = []
        @callback_prefix = "__dwExpr#{object_id.abs}"
      end

      attr_reader :expression_errors

      def evaluate(expression)
        ensure_initialized!
        @sandbox.eval("(#{expression})")
      rescue JsSandbox::BudgetExceededError
        raise
      rescue JsSandbox::SandboxError, MiniRacer::Error => e
        if e.message.include?(NodeOutputProxy::MULTIPLE_MATCHING_ITEMS_MESSAGE)
          raise RuntimeError, NodeOutputProxy::MULTIPLE_MATCHING_ITEMS_MESSAGE
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
        @sandbox = nil
      end

      def rebind_input_item(item, item_index: 0)
        ensure_initialized!
        @sandbox.rebind_expression_item(item, item_index:)
      end

      private

      def ensure_initialized!
        return if @initialized
        inject_expression_data!
        @initialized = true
      end

      def inject_expression_data!
        data = build_expression_data
        @sandbox.attach(fetch_node_item_callback, method(:fetch_node_item_for_expression))
        @sandbox.attach(fetch_node_items_callback, method(:fetch_node_items_for_expression))
        @sandbox.attach(fetch_node_params_callback, method(:fetch_node_params_for_expression))
        @sandbox.attach(node_executed_callback, method(:node_executed_for_expression?))
        @sandbox.attach(fetch_input_items_callback, method(:fetch_input_items))
        @sandbox.declare_json("__data", data)
        @sandbox.eval(expression_setup_js)
      end

      def fetch_node_item_callback
        "#{@callback_prefix}FetchNodeItem"
      end

      def fetch_node_items_callback
        "#{@callback_prefix}FetchNodeItems"
      end

      def fetch_node_params_callback
        "#{@callback_prefix}FetchNodeParams"
      end

      def node_executed_callback
        "#{@callback_prefix}NodeExecuted"
      end

      def fetch_input_items_callback
        "#{@callback_prefix}FetchInputItems"
      end

      def build_expression_data
        {
          "$json" => @context.fetch("$json") { {} },
          "$trigger" => @context.fetch("$trigger") { {} },
          "$execution" => @context.fetch("__execution") { {} },
          "$itemIndex" => @context.fetch("$itemIndex") { 0 },
          "__inputItem" =>
            @context.fetch("__input_item") { { "json" => @context.fetch("$json") { {} } } },
          "__inputParams" => @context.fetch("__input_params") { {} },
          "__inputContext" => @context.fetch("__input_context") { {} },
          "__node_contexts" => @context.fetch("__node_contexts") { {} },
          "__nodeParametersByName" => @context.fetch("__node_parameters_by_name") { {} },
        }
      end

      def fetch_node_item_for_expression(name, item_index = nil)
        name_str = name.to_s
        return {}.to_json if name_str.start_with?("_") || BLOCKED_NODE_NAMES.include?(name_str)

        JsSandbox.serialize_json_payload(
          node_output_proxy.item(name_str, item_index: item_index),
          label: "$().item",
        )
      end

      def fetch_node_items_for_expression(name, branch_index = nil, run_index = nil)
        name_str = name.to_s
        return [].to_json if name_str.start_with?("_") || BLOCKED_NODE_NAMES.include?(name_str)

        JsSandbox.serialize_json_payload(
          node_output_proxy.all(name_str, branch_index:, run_index:),
          label: "$().all()",
        )
      end

      def fetch_node_params_for_expression(name)
        name_str = name.to_s
        return {}.to_json if name_str.start_with?("_") || BLOCKED_NODE_NAMES.include?(name_str)

        JsSandbox.serialize_json_payload(node_output_proxy.params(name_str), label: "$().params")
      end

      def node_executed_for_expression?(name)
        name_str = name.to_s
        return false if name_str.start_with?("_") || BLOCKED_NODE_NAMES.include?(name_str)

        node_output_proxy.executed?(name_str)
      end

      def fetch_input_items
        JsSandbox.serialize_json_payload(
          @context.fetch("__input_items") { [] },
          label: "$input.all()",
        )
      end

      def expression_setup_js
        <<~JS
          function __WorkflowExpressionInput(item) {
            this.item = item;
            this.params = __data["__inputParams"];
            this.context = __data["__inputContext"];
          }

          __WorkflowExpressionInput.prototype.all = function() {
            return JSON.parse(#{fetch_input_items_callback}());
          };

          __WorkflowExpressionInput.prototype.first = function() {
            var items = this.all();
            return items[0] || { json: {} };
          };

          __WorkflowExpressionInput.prototype.last = function() {
            var items = this.all();
            return items[items.length - 1] || { json: {} };
          };

          var $input = new __WorkflowExpressionInput(__data["__inputItem"]);
          Object.defineProperty(this, '$json', {
            get: function() { return $input.item.json; },
            set: function(value) {
              $input.item.json = value;
              __data["$json"] = value;
            },
            configurable: true
          });
          Object.defineProperty(this, '$itemIndex', {
            get: function() { return __data["$itemIndex"]; },
            set: function(value) { __data["$itemIndex"] = value; },
            configurable: true
          });
          var $trigger = __data["$trigger"];
          var $execution = __data["$execution"];
          function __WorkflowExpressionNode(name) {
            this.name = name;
          }

          Object.defineProperty(__WorkflowExpressionNode.prototype, 'item', {
            get: function() {
              return JSON.parse(#{fetch_node_item_callback}(this.name, __data["$itemIndex"]));
            },
            configurable: true
          });

          __WorkflowExpressionNode.prototype.itemMatching = function(itemIndex) {
            if (itemIndex === undefined) {
              throw new Error("Missing item index for .itemMatching()");
            }
            return JSON.parse(#{fetch_node_item_callback}(this.name, itemIndex));
          };

          __WorkflowExpressionNode.prototype.pairedItem = function(itemIndex) {
            return JSON.parse(
              #{fetch_node_item_callback}(
                this.name,
                itemIndex === undefined ? __data["$itemIndex"] : itemIndex
              )
            );
          };

          Object.defineProperty(__WorkflowExpressionNode.prototype, 'context', {
            get: function() {
              return __data.__node_contexts[this.name] || {};
            },
            configurable: true
          });

          Object.defineProperty(__WorkflowExpressionNode.prototype, 'params', {
            get: function() {
              return JSON.parse(#{fetch_node_params_callback}(this.name));
            },
            configurable: true
          });

          Object.defineProperty(__WorkflowExpressionNode.prototype, 'isExecuted', {
            get: function() {
              return #{node_executed_callback}(this.name);
            },
            configurable: true
          });

          __WorkflowExpressionNode.prototype.all = function(branchIndex, runIndex) {
            return JSON.parse(#{fetch_node_items_callback}(this.name, branchIndex, runIndex));
          };

          __WorkflowExpressionNode.prototype.first = function(branchIndex, runIndex) {
            var items = this.all(branchIndex, runIndex);
            return items[0] || { json: {} };
          };

          __WorkflowExpressionNode.prototype.last = function(branchIndex, runIndex) {
            var items = this.all(branchIndex, runIndex);
            return items[items.length - 1] || { json: {} };
          };

          Object.defineProperty(this, '$', {
            value: function(name) {
              return new __WorkflowExpressionNode(name);
            },
            configurable: true,
            writable: false
          });
        JS
      end

      def node_output_proxy
        @node_output_proxy ||= NodeOutputProxy.new(@context)
      end
    end
  end
end
