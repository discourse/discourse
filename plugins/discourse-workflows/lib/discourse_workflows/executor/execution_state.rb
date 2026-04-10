# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ExecutionState
      include ExecutionSession

      attr_reader :workflow,
                  :trigger_node_id,
                  :trigger_data,
                  :execution,
                  :context,
                  :waiting_node,
                  :waiting_step,
                  :user,
                  :workflow_snapshot_data

      def initialize(workflow:, trigger_node_id:, trigger_data:, options: ExecutionOptions.new)
        @workflow = workflow
        @trigger_node_id = trigger_node_id.to_s
        @trigger_data = trigger_data
        @user = options.user
        @execution_mode = options.execution_mode
        reset_runtime_state
      end

      def run_data
        @run_data_tracker.serializable_data
      end

      def start!
        @workflow_snapshot_data = WorkflowSnapshot.snapshot(workflow)

        @execution =
          DiscourseWorkflows::Execution.create!(
            workflow: workflow,
            trigger_node_id: @trigger_node_id,
            status: :running,
            trigger_data: trigger_data,
            execution_mode: @execution_mode,
            started_at: Time.current,
          )

        @resume_token = SecureRandom.uuid
        @context = { "trigger" => trigger_data, "__resume_token" => @resume_token }
        @node_contexts = {}
        @step_position = 0
        @queue = ExecutionQueue.new
        @run_data_tracker = RunDataTracker.new
        clear_wait
      end

      def resume!(execution)
        @execution = execution
        ed = execution.execution_data

        if ed
          resume_with_data!(execution, ed)
        else
          resume_without_data!(execution)
        end
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

      def waiting_config
        { "node_contexts" => @node_contexts, "step_position" => @step_position }
      end

      def clear_wait
        @waiting_node = nil
        @waiting_step = nil
      end

      def save!(max_size: 5.megabytes)
        ed = execution.execution_data || execution.build_execution_data
        json_data = { "run_data" => run_data, "context" => @context }.to_json
        if json_data.bytesize > max_size
          Rails.logger.warn(
            "discourse-workflows: execution data for execution #{execution.id} " \
              "exceeds #{max_size} bytes, truncating context",
          )
          json_data = { "run_data" => run_data, "context" => { "_truncated" => true } }.to_json
        end
        ed.update!(data: json_data, workflow_data: @workflow_snapshot_data)
      end

      def last_failed_step
        @run_data_tracker.last_failed_step
      end

      def find_step_in_run_data(node_id:, status: nil)
        @run_data_tracker.find_step(node_id: node_id, status: status)
      end

      def update_step_in_run_data!(node_id:, from_status:, updates:)
        @run_data_tracker.update_step!(node_id: node_id, from_status: from_status, updates: updates)
      end

      private

      def resume_with_data!(execution, ed)
        @workflow_snapshot_data = ed.workflow_data
        @run_data_tracker = RunDataTracker.new(ed.run_data)
        @context = ed.context_data
        @resume_token = @context["__resume_token"]
        restore_waiting_config!(execution)
        @queue = ExecutionQueue.new
        clear_wait
      end

      def resume_without_data!(execution)
        reset_runtime_state
        @resume_token = nil
        restore_waiting_config!(execution)
      end

      def restore_waiting_config!(execution)
        @node_contexts = execution.waiting_config.fetch("node_contexts") { {} }.deep_stringify_keys
        @step_position =
          execution.waiting_config.fetch("step_position") { @run_data_tracker.total_steps }
      end

      EXECUTION_VALUE_SOURCES = {
        "id" => ->(state) { state.execution&.id },
        "workflow_id" => ->(state) { state.workflow&.id },
        "workflow_name" => ->(state) { state.workflow&.name },
        "resume_url" =>
          lambda do |state|
            token = state.instance_variable_get(:@resume_token)
            return unless token
            signature = DiscourseWorkflows::HmacSigner.sign(token)
            "#{Discourse.base_url}/workflows/webhooks/#{token}:#{signature}"
          end,
      }.freeze

      def execution_variables
        @execution_variables ||= build_execution_variables
      end

      def build_execution_variables
        schema_fields = ExpressionContextSchema.environment_symbols.dig("$execution", :fields) || {}
        schema_fields.each_with_object({}) do |(field_name, _), vars|
          source = EXECUTION_VALUE_SOURCES[field_name]
          value = source&.call(self)
          vars[field_name] = value unless value.nil?
        end
      end

      def reset_runtime_state
        @context = {}
        @node_contexts = {}
        @step_position = 0
        @queue = ExecutionQueue.new
        @run_data_tracker = RunDataTracker.new
        @workflow_snapshot_data = {}
        clear_wait
      end
    end
  end
end
