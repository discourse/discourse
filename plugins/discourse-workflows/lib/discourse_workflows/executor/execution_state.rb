# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ExecutionState
      attr_reader :workflow,
                  :trigger_data,
                  :execution,
                  :context,
                  :waiting_node,
                  :waiting_step,
                  :user

      def initialize(workflow:, trigger_node:, trigger_data:, user: nil, execution_mode: :normal)
        @workflow = workflow
        @trigger_node = trigger_node
        @trigger_data = trigger_data
        @user = user
        @execution_mode = execution_mode
        reset_runtime_state
      end

      def start!
        @execution =
          DiscourseWorkflows::Execution.create!(
            workflow: workflow,
            trigger_node_id: @trigger_node.id,
            status: :running,
            trigger_data: trigger_data,
            workflow_data: WorkflowSnapshot.snapshot(workflow),
            execution_mode: @execution_mode,
            started_at: Time.current,
          )

        @context = { "trigger" => trigger_data }
        @node_contexts = {}
        @step_position = 0
        @queue = []
        clear_wait
      end

      def resume!(execution)
        @execution = execution
        @context = execution.context.deep_stringify_keys
        @node_contexts = (execution.waiting_config["node_contexts"] || {}).deep_stringify_keys
        @step_position = execution.waiting_config["step_position"] || execution.steps.count
        @queue = []
        clear_wait
      end

      def clear_waiting_execution!
        execution.update!(
          status: :running,
          waiting_node_id: nil,
          waiting_until: nil,
          waiting_config: {
          },
        )
        clear_wait
      end

      def store_context(key, value)
        @context[key] = value
      end

      def resolver_context(extra_context = {})
        @context.merge("_node_contexts" => @node_contexts, **extra_context)
      end

      def node_context_for(node)
        @node_contexts[node.name] ||= {}
      end

      def next_step_position
        position = @step_position
        @step_position += 1
        position
      end

      def enqueue(node, items)
        @queue << [node, items]
      end

      def queued?
        @queue.any?
      end

      def shift_queue
        @queue.shift
      end

      def waiting_config
        { "node_contexts" => @node_contexts, "step_position" => @step_position }
      end

      def mark_wait(node:, step:)
        @waiting_node = node
        @waiting_step = step
      end

      def clear_wait
        @waiting_node = nil
        @waiting_step = nil
      end

      private

      def reset_runtime_state
        @context = {}
        @node_contexts = {}
        @step_position = 0
        @queue = []
        clear_wait
      end
    end
  end
end
