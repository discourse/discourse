# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class NodeRouter
      def initialize(
        context:,
        journal:,
        runtime:,
        step_runner:,
        snapshot:,
        user:,
        run_as_user_proc:
      )
        @context = context
        @journal = journal
        @runtime = runtime
        @step_runner = step_runner
        @snapshot = snapshot
        @user = user
        @run_as_user_proc = run_as_user_proc
      end

      def execute_node(node, input_items)
        node_type_class =
          DiscourseWorkflows::Registry.find_node_type(node.type, version: node.type_version)
        return unknown_node_commands(node, input_items) if node_type_class.nil?

        outcome = run_node(node, node_type_class, input_items)
        outcome_to_commands(node, node_type_class, outcome)
      end

      def record_trigger_step(node, items)
        record_step(node, [], status: Step::SUCCESS, output: items)
      end

      def enqueue_downstream(node, output_name, items)
        @snapshot
          .connections_from(node)
          .each do |connection|
            next if connection.source_output.present? && connection.source_output != output_name
            next if connection.source_output.blank? && output_name != "main"
            target = @snapshot.target_node(connection)
            @runtime.enqueue(target, items) if target
          end
      end

      private

      def run_node(node, node_type_class, input_items)
        @step_runner.run(node, input_items, node_type_class) do |instance, resolver|
          exec_ctx =
            NodeExecutionContext.new(
              input_items: input_items,
              configuration: node.configuration,
              configuration_schema: node_type_class.configuration_schema,
              node_context: @context.node_context_for(node),
              user: @user,
              run_as_user: @run_as_user_proc.call,
              resolver: resolver,
              vars: @runtime.preloaded_vars,
            )
          result = instance.execute(exec_ctx)
          [result, exec_ctx]
        end
      end

      def outcome_to_commands(node, node_type_class, outcome)
        if outcome.success?
          route_result(node, node_type_class, outcome.result)
        elsif outcome.wait?
          [RoutingCommand::Pause.new(node: node, step: outcome.step, wait: outcome.wait)]
        elsif outcome.error?
          raise outcome.error
        end
      end

      def route_result(node, node_type_class, result)
        ports = node_type_class.ports
        commands = []

        all_items = result.all_items(ports: ports)
        if all_items.any?
          commands << RoutingCommand::StoreContext.new(name: node.name, items: all_items)
        end

        output_arrays = result.output_arrays(ports: ports)
        output_arrays.each_with_index do |items, index|
          next if items.empty?
          port_key = ports.dig(index, :key) || "main"
          commands += downstream_commands(node, port_key, items)
        end

        commands
      end

      def downstream_commands(node, output_name, items)
        @snapshot
          .connections_from(node)
          .filter_map do |connection|
            next if connection.source_output.present? && connection.source_output != output_name
            next if connection.source_output.blank? && output_name != "main"
            target = @snapshot.target_node(connection)
            RoutingCommand::Enqueue.new(node: target, items: items) if target
          end
      end

      def unknown_node_commands(node, input_items)
        Rails.logger.warn(
          "discourse-workflows: unknown node type '#{node.type}' (version: #{node.type_version}) " \
            "in workflow #{@context.workflow.id}, skipping node '#{node.name}'",
        )
        step =
          Step.build(
            node: node,
            position: @journal.next_step_position,
            input: input_items,
            status: Step::ERROR,
            error: "Unknown node type '#{node.type}'",
          )
        [RoutingCommand::RecordStep.new(node_name: node.name, step: step)]
      end

      def record_step(node, input_items, status:, output: [], error: nil)
        step =
          Step.build(
            node: node,
            position: @journal.next_step_position,
            input: input_items,
            status: status,
            output: output,
            error: error,
          )
        @journal.record_step(node.name, step)
      end
    end
  end
end
