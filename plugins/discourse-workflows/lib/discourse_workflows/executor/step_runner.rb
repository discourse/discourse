# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class StepRunner
      def initialize(state)
        @state = state
      end

      def run(node, input_items, node_type_class)
        resolver = build_resolver(node, input_items)
        instance = node_type_class.new(configuration: node.configuration)
        step = build_step(node, input_items)
        @current_exec_ctx = nil

        execute_step(instance, step) do
          block_return = yield(instance, resolver)
          if block_return.is_a?(Array) && block_return.last.is_a?(NodeExecutionContext)
            result, @current_exec_ctx = block_return
            result
          else
            block_return
          end
        end
      ensure
        @current_exec_ctx&.collect_errors!
        populate_resolved!(step, instance, resolver, node.configuration)
        @current_exec_ctx = nil
        resolver.dispose
      end

      private

      def execute_step(instance, step)
        result = yield
        return StepOutcome.wait(step: step, wait: result) if wait_request?(result)

        error = finalize_success!(step, instance, result)
        return StepOutcome.error(step: step, error: error) if error

        StepOutcome.success(step: step, result: result)
      rescue => e
        finalize_error!(step, instance, e)
        StepOutcome.error(step: step, error: e)
      end

      def finalize_success!(step, instance, result)
        error = process_step_log!(step, instance)
        return error if error

        conditions = build_conditions(instance)
        step.add_metadata("conditions", conditions) if conditions.present?

        primary_empty = result.is_a?(Array) && result.first.is_a?(Array) && result.first.empty?
        flat_output = result.is_a?(Array) && result.first.is_a?(Array) ? result.flatten(1) : result
        if instance.class.branching? && primary_empty
          step.filter!(output: flat_output)
        else
          step.succeed!(output: flat_output)
        end

        nil
      end

      def process_step_log!(step, instance)
        step_log = collect_log(instance)
        attach_log!(step, step_log)
        fail_step_with_log!(step, step_log) if step_log&.errors?
      end

      def fail_step_with_log!(step, step_log)
        step.fail!(step_log.error_summary)
        StandardError.new(step.error)
      end

      def finalize_error!(step, instance, error)
        step_log = collect_log(instance)
        attach_log!(step, step_log)
        step.fail!(error.message)
      end

      def build_resolver(node, input_items)
        base = @state.resolver_context
        first_json = input_items.first&.dig("json")
        context = first_json ? base.merge("$json" => first_json) : base
        ExpressionResolver.new(context, user: @state.user, sandbox: @state.shared_sandbox)
      end

      def build_step(node, input_items)
        step =
          Step.build(
            node: node,
            position: @state.next_step_position,
            input: input_items,
            metadata: {
            },
          )
        @state.record_step(node.name, step)
        step
      end

      SENSITIVE_HEADER_PATTERNS = [/key/i, /secret/i, /token/i, /authorization/i, /password/i]

      def populate_resolved!(step, instance, resolver, raw_config)
        return unless step
        resolved = @current_exec_ctx&.resolved_config || resolver.resolve_hash(raw_config)
        step.add_metadata("resolved_configuration", redact_sensitive_headers(resolved))
      end

      def build_conditions(instance)
        details = @current_exec_ctx&.condition_details
        return if details.blank?

        raw_conditions = @current_exec_ctx.resolved_config&.fetch("conditions", nil) || []

        details.each_with_index.map do |detail, index|
          raw_condition = raw_conditions[index] || {}
          detail.merge(
            "leftExpression" => raw_condition["leftValue"],
            "rightExpression" => raw_condition["rightValue"],
          )
        end
      end

      def collect_log(_instance)
        log = @current_exec_ctx&.log || StepLog.new
        errors = @current_exec_ctx&.expression_errors || []
        errors.each { |err| log.error("#{err[:expression]}: #{err[:error]}") } if errors.present?
        log
      end

      def attach_log!(step, step_log)
        return if step_log.nil? || step_log.empty?
        step.add_metadata("logs", step_log.as_json)
      end

      def wait_request?(result)
        result.is_a?(WaitForResume)
      end

      def redact_sensitive_headers(config)
        return config unless config.is_a?(Hash) && config["headers"].is_a?(Array)
        filter = ActiveSupport::ParameterFilter.new(SENSITIVE_HEADER_PATTERNS)
        filtered_headers =
          config["headers"].map do |header|
            next header unless header.is_a?(Hash) && header["key"].present?
            filtered = filter.filter(header["key"] => header["value"])
            header.merge("value" => filtered[header["key"]])
          end
        config.merge("headers" => filtered_headers)
      end
    end
  end
end
