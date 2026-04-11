# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ExecutionPersistence
      delegate :workflow, :trigger_data, to: :@execution_context

      attr_reader :trigger_node_id, :execution, :workflow_snapshot_data

      def initialize(trigger_node_id:, execution_context:, steps_journal:, execution_mode:)
        @trigger_node_id = trigger_node_id.to_s
        @execution_context = execution_context
        @steps_journal = steps_journal
        @execution_mode = execution_mode
        @workflow_snapshot_data = {}
      end

      def start!
        @workflow_snapshot_data = WorkflowSnapshot.snapshot(workflow)
        @execution = create_execution!
        reset_collaborators!
        @execution
      end

      def resume!(execution)
        @execution = execution
        @execution_context.execution = execution
        restore_from!(execution.execution_data)
        @execution
      end

      def save!(max_size: 5.megabytes)
        ed = execution.execution_data || execution.build_execution_data
        ed.update!(data: serialize_execution_data(max_size), workflow_data: @workflow_snapshot_data)
      end

      def waiting_config
        {
          "node_contexts" => @execution_context.node_contexts,
          "step_position" => @steps_journal.step_position,
        }
      end

      def pause_waiting_execution!(
        node:,
        waiting_until: nil,
        extra_config: {},
        max_size: 5.megabytes
      )
        execution.update!(
          status: :waiting,
          waiting_node_id: node.id,
          waiting_until: waiting_until,
          waiting_config: waiting_config.merge(extra_config),
        )
        save!(max_size: max_size)
        execution
      end

      def clear_waiting_execution!
        execution.update!(
          status: :running,
          waiting_node_id: nil,
          waiting_until: nil,
          waiting_config: {
          },
        )
      end

      private

      def create_execution!
        DiscourseWorkflows::Execution.create!(
          workflow: workflow,
          trigger_node_id: @trigger_node_id,
          status: :running,
          trigger_data: trigger_data,
          execution_mode: @execution_mode,
          started_at: Time.current,
        )
      end

      def reset_collaborators!
        @execution_context.execution = @execution
        @steps_journal.reset!
        @execution_context.reset!(resume_token: SecureRandom.uuid)
      end

      def restore_from!(execution_data)
        config = execution.waiting_config || {}
        @workflow_snapshot_data =
          execution_data&.workflow_data.presence || WorkflowSnapshot.snapshot(workflow)
        @steps_journal.restore!(
          entries: execution_data&.entries || {},
          step_position: config["step_position"],
        )
        @execution_context.restore!(
          context: execution_data&.context_data || {},
          node_contexts: config.fetch("node_contexts") { {} },
        )
      end

      def serialize_execution_data(max_size)
        entries = @steps_journal.entries
        context = @execution_context.context
        json_data = { "entries" => entries, "context" => context }.to_json
        return json_data if json_data.bytesize <= max_size

        Rails.logger.warn(
          "discourse-workflows: execution data for execution #{execution.id} " \
            "exceeds #{max_size} bytes, truncating context",
        )
        { "entries" => entries, "context" => { "__truncated" => true } }.to_json
      end
    end
  end
end
