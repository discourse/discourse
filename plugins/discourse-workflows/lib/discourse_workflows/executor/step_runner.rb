# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class StepRunner
      def initialize(state)
        @state = state
      end

      def run(node, input_items, node_type_class = nil)
        node_type_class ||=
          DiscourseWorkflows::Registry.find_node_type(node.type, version: node.type_version)
        raw_config = node.configuration.deep_stringify_keys
        resolved_config = resolve_config(node, input_items, raw_config)
        instance =
          node_type_class.new(configuration: config_for_instance(node, raw_config, resolved_config))
        step = create_step(node, input_items, resolved_config)

        begin
          result = yield instance
          update_step_success!(step, node, raw_config, instance, result)
          result
        rescue WaitForHuman
          @state.mark_wait(node: node, step: step)
          raise
        rescue => e
          step.update!(status: :error, error: e.message, finished_at: Time.current)
          raise
        end
      end

      private

      def resolve_config(node, input_items, raw_config)
        resolver = ExpressionResolver.new(resolver_context(node, input_items))
        resolver.resolve_hash(raw_config)
      end

      def resolver_context(node, input_items)
        if node.condition? && input_items.first.is_a?(Hash)
          @state.resolver_context("$json" => input_items.first["json"])
        else
          @state.resolver_context
        end
      end

      # Action and condition nodes resolve $json per item. Core nodes receive
      # configuration that has already been resolved against the execution context.
      def config_for_instance(node, raw_config, resolved_config)
        node.action? || node.condition? ? raw_config : resolved_config
      end

      def create_step(node, input_items, resolved_config)
        DiscourseWorkflows::ExecutionStep.create!(
          execution: @state.execution,
          node_id: node.id,
          node_name: node.name,
          node_type: node.type,
          position: @state.next_step_position,
          status: :running,
          input: input_items,
          metadata: {
            "resolved_configuration" => resolved_config,
          },
          started_at: Time.current,
        )
      end

      def update_step_success!(step, node, raw_config, instance, result)
        metadata = step.metadata

        conditions_metadata = build_conditions_metadata(node, raw_config, instance)
        metadata["conditions"] = conditions_metadata if conditions_metadata.present?

        metadata["logs"] = instance.logs if instance.respond_to?(:logs) && instance.logs.present?

        step.update!(
          metadata: metadata,
          status: step_status(node, result),
          output: result,
          finished_at: Time.current,
        )
      end

      def build_conditions_metadata(node, raw_config, instance)
        unless node.condition? && instance.respond_to?(:condition_details) &&
                 instance.condition_details
          return
        end

        raw_conditions = raw_config["conditions"] || []

        instance.condition_details.each_with_index.map do |detail, index|
          raw_condition = raw_conditions[index] || {}

          detail.merge(
            "leftExpression" => raw_condition["leftValue"],
            "rightExpression" => raw_condition["rightValue"],
          )
        end
      end

      def step_status(node, result)
        return :success unless node.condition?

        true_items = result.is_a?(Hash) ? (result["true"] || []) : []
        true_items.empty? ? :filtered : :success
      end
    end
  end
end
