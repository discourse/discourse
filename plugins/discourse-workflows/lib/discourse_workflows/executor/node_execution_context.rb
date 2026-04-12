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
                  :resolved_config,
                  :log,
                  :execution_id,
                  :resume_token,
                  :node_id

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
        @resolved_config = nil
        @log = StepLog.new
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
          JsSandbox.new(@resolver_context, user: @user, vars: @vars, capture_logs: capture_logs)
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

      private

      def with_item(item)
        @resolver.with_item(item["json"]) { yield }
      end

      def resolve_parameter(name, schema)
        if schema.is_a?(Hash) && schema.dig(:ui, :control) == :condition_builder
          conditions = @configuration.fetch("conditions") { [] }
          combinator = @configuration.fetch("combinator") { "and" }
          options = @configuration.fetch("options") { {} }
          result =
            Executor::FilterParameter.execute_filter(conditions, combinator, options, @resolver)
          @condition_details.concat(result["details"]) if @condition_details.empty?
          result["passed"]
        else
          @resolver.resolve(@configuration[name])
        end
      end

      def resolve_all_parameters
        resolved = @resolver.resolve_hash(@configuration)
        @resolved_config ||= resolved
        resolved
      end
    end
  end
end
