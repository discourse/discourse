# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class CodeRunner
      RUN_CODE = "runCode"
      RUN_ONCE_FOR_ALL_ITEMS = "runOnceForAllItems"
      RUN_ONCE_FOR_EACH_ITEM = "runOnceForEachItem"
      JAVASCRIPT_UNDEFINED =
        Object
          .new
          .tap do |undefined|
            def undefined.to_s
              "undefined"
            end

            def undefined.inspect
              "undefined"
            end
          end
          .freeze

      def initialize(
        input_items:,
        parameters:,
        input_context:,
        resolver_context:,
        user:,
        vars:,
        flow_context:,
        runtime_state:
      )
        @input_items = input_items
        @parameters = parameters
        @input_context = input_context
        @resolver_context = resolver_context || {}
        @user = user
        @vars = vars
        @flow_context = flow_context || {}
        @runtime_state = runtime_state
      end

      def run(settings, item_index)
        item_index = normalize_item_index(item_index)

        case settings.fetch("nodeMode")
        when RUN_CODE
          run_javascript_code(settings, item_index)
        when RUN_ONCE_FOR_ALL_ITEMS
          run_javascript_for_all_items(settings, item_index)
        when RUN_ONCE_FOR_EACH_ITEM
          run_javascript_for_each_item(settings)
        else
          raise ArgumentError, "Unsupported JavaScript node mode: #{settings["nodeMode"]}"
        end
      end

      private

      def run_javascript_code(settings, item_index)
        with_javascript_sandbox(item_index:) do |sandbox|
          declare_additional_properties(sandbox, settings["additionalProperties"])
          raw_javascript_result(sandbox, settings.fetch("code"))
        end
      end

      def run_javascript_for_all_items(settings, item_index)
        with_javascript_sandbox(item_index:) do |sandbox|
          setup_code_sandbox!(
            sandbox,
            @input_items,
            @parameters,
            input_context,
            item_alias: @input_items.fetch(item_index) { @input_items.first || { "json" => {} } },
          )
          declare_additional_properties(
            sandbox,
            { "items" => @input_items }.merge(settings["additionalProperties"] || {}),
          )
          raw_javascript_result(sandbox, settings.fetch("code"))
        end
      end

      def run_javascript_for_each_item(settings)
        chunk = settings["chunk"] || {}
        start_index = chunk.fetch("startIndex") { 0 }.to_i
        end_index = start_index + chunk.fetch("count") { @input_items.length }.to_i

        with_javascript_sandbox(item_index: start_index) do |sandbox|
          setup_code_sandbox!(
            sandbox,
            @input_items,
            @parameters,
            input_context,
            item_alias: @input_items[start_index] || { "json" => {} },
          )
          declare_additional_properties(sandbox, settings["additionalProperties"])

          @input_items[start_index...end_index].each_with_index.filter_map do |item, offset|
            item_index = start_index + offset
            sandbox.rebind_code_item(item, item_index: item_index)
            sandbox.eval("item = $input.item;")
            result = raw_javascript_result(sandbox, settings.fetch("code"))
            next if result.nil?

            result
          end
        end
      end

      def with_javascript_sandbox(capture_logs: true, item_index: 0)
        sandbox =
          JsSandbox.new(
            resolver_context_for_item_index(item_index),
            user: @user,
            vars: @vars,
            capture_logs: capture_logs,
            budget_tracker: sandbox_budget_tracker,
          )
        yield sandbox
      ensure
        @runtime_state.log.merge(sandbox.log) if capture_logs && sandbox&.log
        sandbox&.dispose
      end

      def sandbox_budget_tracker
        @sandbox_budget_tracker ||= DiscourseWorkflows::SandboxBudget.new(@flow_context)
      end

      def resolver_context_for_item_index(item_index)
        item = @input_items.fetch(item_index) { { "json" => {} } }
        @resolver_context.merge(
          "__input_item" => item,
          "$json" => item.fetch("json") { {} },
          "$itemIndex" => item_index,
        )
      end

      def declare_additional_properties(sandbox, additional_properties)
        (additional_properties || {}).each do |name, value|
          name = name.to_s
          unless js_identifier?(name)
            raise ArgumentError, "Invalid JavaScript property name: #{name}"
          end

          sandbox.declare_json(name, value)
        end
      end

      def setup_code_sandbox!(sandbox, input_items, input_params, input_context, item_alias:)
        sandbox.declare_json("__allInputItems", input_items)
        sandbox.declare_json("__inputParams", input_params)
        sandbox.declare_json("__inputContext", input_context)
        sandbox.declare_json("__initialItem", item_alias)
        sandbox.eval(<<~JS)
          function __WorkflowCodeInput(item) {
            this.item = item;
            this.params = __inputParams;
            this.context = __inputContext;
          }

          __WorkflowCodeInput.prototype.all = function() {
            if (arguments.length) {
              throw new Error("$input.all() should have no arguments");
            }

            return __allInputItems;
          };

          __WorkflowCodeInput.prototype.first = function() {
            if (arguments.length) {
              throw new Error("$input.first() should have no arguments");
            }

            return __allInputItems[0] || { json: {} };
          };

          __WorkflowCodeInput.prototype.last = function() {
            if (arguments.length) {
              throw new Error("$input.last() should have no arguments");
            }

            return __allInputItems[__allInputItems.length - 1] || { json: {} };
          };

          var $input = new __WorkflowCodeInput(__initialItem);
          var __itemIndex = 0;
          var item = $input.item;
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

      def evaluate_code(sandbox, code)
        sandbox.eval(<<~JS)
          (function() {
            var __discourseWorkflowsCodeResult = (function() { #{code} })();

            if (__discourseWorkflowsCodeResult === null) {
              return { type: "null" };
            }

            if (typeof __discourseWorkflowsCodeResult === "undefined") {
              return { type: "undefined" };
            }

            return {
              type: typeof __discourseWorkflowsCodeResult,
              value: __discourseWorkflowsCodeResult
            };
          })()
        JS
      end

      def raw_javascript_result(sandbox, code)
        result = evaluate_code(sandbox, code)

        case result["type"]
        when "null"
          nil
        when "undefined"
          JAVASCRIPT_UNDEFINED
        else
          result["value"]
        end
      end

      def input_context
        @input_context.respond_to?(:call) ? @input_context.call : @input_context
      end

      def js_identifier?(name)
        name.match?(/\A[$A-Za-z_][$0-9A-Za-z_]*\z/)
      end

      def normalize_item_index(item_index)
        return 0 if item_index.nil?
        return item_index if item_index.is_a?(Integer)

        raise ArgumentError, "item_index must be an Integer"
      end
    end
  end
end
