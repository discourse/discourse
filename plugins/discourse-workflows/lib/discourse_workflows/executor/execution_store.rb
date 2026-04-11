# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ExecutionStore
      include FormExecutionChannel

      MAX_EXECUTION_DATA_SIZE = 5.megabytes

      delegate :workflow, :trigger_data, to: :@execution_context

      attr_reader :trigger_node_id, :execution, :workflow_snapshot_data

      def initialize(trigger_node_id:, execution_context:, execution_mode:, options:)
        @trigger_node_id = trigger_node_id.to_s
        @execution_context = execution_context
        @execution_mode = execution_mode
        @options = options
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

      def finish!(steps:)
        save!(steps)
        execution.update!(
          status: :success,
          finished_at: Time.current,
          run_time_ms: Execution.compute_run_time_ms(steps),
        )
        publish_form_notification(:success)
        execution
      end

      def fail!(error:, steps: [])
        save!(steps)
        execution.update!(
          status: :error,
          error: error.message.to_s.truncate(1000),
          finished_at: Time.current,
          run_time_ms: Execution.compute_run_time_ms(steps),
        )
        trigger_error_workflow(error, steps)
        publish_form_notification(:error)
        execution
      end

      def create_terminal(status)
        now = Time.current

        DiscourseWorkflows::Execution.create!(
          workflow: workflow,
          trigger_node_id: @trigger_node_id,
          status: status,
          trigger_data: trigger_data,
          execution_mode: @options.execution_mode,
          started_at: now,
          finished_at: now,
        )
      end

      def pause_waiting_execution!(node:, waiting_until: nil, extra_config: {}, steps: [])
        execution.update!(
          status: :waiting,
          waiting_node_id: node.id,
          waiting_until: waiting_until,
          waiting_config: waiting_config(steps).merge(extra_config),
        )
        save!(steps)
        execution
      end

      def clear_waiting_execution!
        execution.update!(
          status: :running,
          waiting_node_id: nil,
          waiting_until: nil,
          waiting_config: {},
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
        @execution_context.reset!(resume_token: SecureRandom.uuid)
      end

      def restore_from!(execution_data)
        config = execution.waiting_config || {}
        @workflow_snapshot_data =
          execution_data&.workflow_data.presence || WorkflowSnapshot.snapshot(workflow)
        @execution_context.restore!(
          context: execution_data&.context_data || {},
          node_contexts: config.fetch("node_contexts") { {} },
        )
      end

      def save!(steps)
        entries = steps_to_entries(steps)
        context = @execution_context.context

        ed = execution.execution_data || execution.build_execution_data
        json_data = { "entries" => entries, "context" => context }.to_json

        if json_data.bytesize > MAX_EXECUTION_DATA_SIZE
          Rails.logger.warn(
            "discourse-workflows: execution data for execution #{execution.id} " \
              "exceeds #{MAX_EXECUTION_DATA_SIZE} bytes, truncating context",
          )
          json_data = { "entries" => entries, "context" => { "__truncated" => true } }.to_json
        end

        ed.update!(data: json_data, workflow_data: @workflow_snapshot_data)
      end

      def steps_to_entries(steps)
        steps
          .group_by { |s| s.respond_to?(:node_id) ? s.node_id : s["node_id"] }
          .transform_values do |node_steps|
            node_steps.map { |s| s.respond_to?(:to_h) ? s.to_h : s }
          end
      end

      def waiting_config(steps)
        {
          "node_contexts" => @execution_context.node_contexts,
          "step_position" => steps.size,
        }
      end

      def trigger_error_workflow(error, steps)
        ErrorWorkflowTrigger.new(
          workflow,
          steps,
          error_depth: @options.error_depth,
          execution_mode: @options.execution_mode,
        ).trigger_error_workflow(error)
      end

      def publish_form_notification(status)
        return if @workflow_snapshot_data.blank?

        snapshot = WorkflowSnapshot.new(@workflow_snapshot_data)
        trigger_node = snapshot.find_node(@trigger_node_id)
        return unless trigger_node&.type == "trigger:form"

        channel = self.class.form_channel(execution.id)

        case status
        when :success
          form_completion = @execution_context.form_completion
          MessageBus.publish(
            channel,
            { status: "success", form_completion: form_completion }.compact,
          )
        when :error
          MessageBus.publish(channel, { status: "error" })
        end
      end
    end
  end
end
