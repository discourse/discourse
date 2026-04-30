# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ExecutionStore
      include FormExecutionChannel

      MAX_EXECUTION_DATA_SIZE = 5.megabytes
      MAX_STEP_IO_SIZE = 128.kilobytes
      MAX_STEP_STRING_BYTES = 16.kilobytes
      MAX_STEP_COLLECTION_SIZE = 50
      MAX_STEP_IO_DEPTH = 8

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
        publish_execution_node_outputs(steps)
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

      def create_execution_with_status(status)
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

      def pause_waiting_execution!(node:, waiting_until: nil, steps: [])
        execution.update!(
          status: :waiting,
          waiting_node_id: node.id,
          waiting_until: waiting_until,
          resume_token: @execution_context.resume_token,
        )
        save!(steps)
        execution
      end

      def clear_waiting_execution!
        execution.update!(
          status: :running,
          waiting_node_id: nil,
          waiting_until: nil,
          resume_token: nil,
          timeout_action: nil,
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
        @execution_context.reset!
      end

      def restore_from!(execution_data)
        @workflow_snapshot_data =
          execution_data&.workflow_data.presence || WorkflowSnapshot.snapshot(workflow)
        @execution_context.restore!(
          context: execution_data&.context_data || {},
          node_contexts: execution_data&.node_contexts || {},
        )
      end

      def save!(steps)
        entries = steps_to_entries(steps)
        context = @execution_context.context

        ed = execution.execution_data || execution.build_execution_data
        json_data = {
          "entries" => entries,
          "context" => context,
          "node_contexts" => @execution_context.node_contexts,
        }.to_json

        if json_data.bytesize > MAX_EXECUTION_DATA_SIZE
          Rails.logger.warn(
            "discourse-workflows: execution data for execution #{execution.id} " \
              "exceeds #{MAX_EXECUTION_DATA_SIZE} bytes, truncating context",
          )
          json_data = {
            "entries" => entries,
            "context" => {
              "__truncated" => true,
            },
            "node_contexts" => {
            },
          }.to_json
        end

        if json_data.bytesize > MAX_EXECUTION_DATA_SIZE
          Rails.logger.warn(
            "discourse-workflows: execution data for execution #{execution.id} " \
              "still exceeds #{MAX_EXECUTION_DATA_SIZE} bytes, truncating entries",
          )
          json_data = {
            "entries" => compact_entries(entries),
            "context" => {
              "__truncated" => true,
            },
            "node_contexts" => {
            },
          }.to_json
        end

        ed.update!(data: json_data, workflow_data: @workflow_snapshot_data)
      end

      def steps_to_entries(steps)
        steps
          .group_by(&:node_id)
          .transform_values { |node_steps| node_steps.map { |step| step_to_entry(step) } }
      end

      def step_to_entry(step)
        entry = step.to_h
        entry["input"] = bounded_step_io(entry["input"]) if entry.key?("input")
        entry["output"] = bounded_step_io(entry["output"]) if entry.key?("output")
        entry
      end

      def bounded_step_io(value)
        bounded_value = bound_execution_value(value)
        return bounded_value if bounded_value.to_json.bytesize <= MAX_STEP_IO_SIZE

        truncated_value(value, MAX_STEP_IO_SIZE, "step_io_size_limit")
      end

      def bound_execution_value(value, depth = 0)
        return truncated_value(value, nil, "step_io_depth_limit") if depth >= MAX_STEP_IO_DEPTH

        case value
        when String
          bound_string(value)
        when Array
          bound_array(value, depth)
        when Hash
          bound_hash(value, depth)
        else
          value
        end
      end

      def bound_string(value)
        return value if value.bytesize <= MAX_STEP_STRING_BYTES

        {
          "__truncated" => true,
          "__reason" => "step_string_size_limit",
          "__original_bytes" => value.bytesize,
          "preview" => value.byteslice(0, MAX_STEP_STRING_BYTES).scrub,
        }
      end

      def bound_array(value, depth)
        kept_items =
          value
            .first(MAX_STEP_COLLECTION_SIZE)
            .map { |item| bound_execution_value(item, depth + 1) }
        return kept_items if value.size <= MAX_STEP_COLLECTION_SIZE

        kept_items << truncated_value(value, nil, "step_collection_size_limit")
      end

      def bound_hash(value, depth)
        kept_pairs =
          value
            .first(MAX_STEP_COLLECTION_SIZE)
            .to_h { |key, hash_value| [key, bound_execution_value(hash_value, depth + 1)] }
        return kept_pairs if value.size <= MAX_STEP_COLLECTION_SIZE

        kept_pairs.merge(
          "__truncated" => true,
          "__reason" => "step_collection_size_limit",
          "__omitted_keys" => value.size - MAX_STEP_COLLECTION_SIZE,
        )
      end

      def truncated_value(value, max_bytes, reason)
        result = { "__truncated" => true, "__reason" => reason, "__class" => value.class.name }
        result["__max_bytes"] = max_bytes if max_bytes
        result["__original_size"] = value.size if value.respond_to?(:size)
        result
      end

      def compact_entries(entries)
        entries.transform_values do |node_steps|
          Array(node_steps).map do |step|
            step.except("input", "output").merge(
              "input" => truncated_value([], nil, "execution_data_size_limit"),
              "output" => truncated_value([], nil, "execution_data_size_limit"),
            )
          end
        end
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

        channel = self.class.form_channel(execution.id, @execution_context.resume_token)

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

      def publish_execution_node_outputs(steps)
        outputs = {}
        steps.each do |step|
          next unless step.success?
          items = step.output || []
          first_json = items.dig(0, "json")
          outputs[step.node_id] = first_json if first_json.present?
        end

        return if outputs.empty?

        MessageBus.publish(
          "/discourse-workflows/workflow/#{workflow.id}",
          { type: "execution_completed", last_execution_node_outputs: outputs },
          group_ids: [Group::AUTO_GROUPS[:admins]],
        )
      end
    end
  end
end
