# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class NodeExecutionContext
      attr_reader :input_items,
                  :user,
                  :run_as_user,
                  :vars,
                  :expression_errors,
                  :condition_details,
                  :log,
                  :execution_id,
                  :resume_token,
                  :node_id,
                  :waiting_until

      def initialize(
        input_items:,
        configuration: {},
        property_schema: {},
        node_context: {},
        user: nil,
        run_as_user: Discourse.system_user,
        resolver: nil,
        vars: nil,
        execution_id: nil,
        resume_token: nil,
        node_id: nil,
        flow_context: nil,
        resolver_context: nil
      )
        @input_items = input_items
        @configuration = configuration
        @property_schema = property_schema
        @node_context = node_context
        @user = user
        @run_as_user = run_as_user
        @resolver = resolver
        @vars = vars
        @execution_id = execution_id
        @resume_token = resume_token
        @node_id = node_id
        @flow_context = flow_context || {}
        @resolver_context = resolver_context || {}
        @expression_errors = []
        @condition_details = []
        @log = StepLog.new
        @waiting = false
        @waiting_until = nil
      end

      def get_context(scope = :flow)
        case scope
        when :flow
          @flow_context
        when :node
          @node_context
        else
          raise ArgumentError, "Unknown context scope: #{scope}. Use :flow or :node"
        end
      end

      def with_sandbox(capture_logs: false)
        sandbox =
          JsSandbox.new(
            @resolver_context,
            user: @user,
            vars: @vars,
            capture_logs: capture_logs,
            budget_tracker: sandbox_budget_tracker,
          )
        yield sandbox
      ensure
        @log.merge(sandbox.log) if capture_logs && sandbox&.log
        sandbox&.dispose
      end

      def get_parameter(name, item)
        name_str = name.to_s
        schema = @property_schema[name.to_sym] || @property_schema[name_str]
        with_item(item) { resolve_parameter(name_str, schema) }
      end

      def get_parameters(item)
        with_item(item) { resolve_all_parameters }
      end

      def collect_errors!
        @expression_errors = @resolver&.expression_errors || []
      end

      # @deprecated Use {#get_context} instead. Kept for backward compatibility
      #   during transition.
      def node_context
        @node_context
      end

      def put_execution_to_wait(waiting_until = nil)
        @waiting = true
        @waiting_until = waiting_until
      end

      def waiting?
        @waiting == true
      end

      private

      def with_item(item)
        @resolver.with_item(item, item_index: item_index_for(item)) { yield }
      end

      def sandbox_budget_tracker
        @sandbox_budget_tracker ||= DiscourseWorkflows::SandboxBudget.new(@flow_context)
      end

      def item_index_for(item)
        @item_indexes_by_object_id ||=
          @input_items.each_with_index.to_h { |entry, index| [entry.object_id, index] }
        @item_indexes_by_object_id.fetch(item.object_id, 0)
      end

      def resolve_parameter(name, schema)
        if schema.is_a?(Hash) && schema.dig(:ui, :control) == :condition_builder
          conditions = @configuration.fetch("conditions") { [] }
          combinator = @configuration.fetch("combinator") { "and" }
          options = @configuration.fetch("options") { {} }
          result =
            Executor::FilterParameter.execute_filter(conditions, combinator, options, @resolver)
          @condition_details.concat(result["details"])
          result["passed"]
        else
          @resolver.resolve(@configuration[name])
        end
      end

      def resolve_all_parameters
        @resolver.resolve_hash(@configuration)
      end
    end
  end
end
