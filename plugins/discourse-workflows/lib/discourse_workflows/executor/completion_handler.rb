# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class CompletionHandler
      MAX_EXECUTION_DATA_SIZE = 5.megabytes

      attr_writer :snapshot

      def initialize(state:, options:)
        @state = state
        @options = options
        @snapshot = nil
      end

      def finish!
        save!
        @state.execution.update!(
          status: :success,
          finished_at: Time.current,
          run_time_ms: compute_run_time_ms,
        )
        publish_form_completion if form_triggered?
        @state.execution
      end

      def fail!(error)
        save!
        @state.execution.update!(
          status: :error,
          error: error.message.to_s.truncate(1000),
          finished_at: Time.current,
          run_time_ms: compute_run_time_ms,
        )
        publish_form_status("error") if form_triggered?
        error_handler.trigger_error_workflow(error)
        @state.execution
      end

      def wait!(error)
        step = @state.waiting_step
        node = @state.waiting_node
        raise ArgumentError, "waiting step is required to pause execution" if step.nil?
        raise ArgumentError, "waiting node is required to pause execution" if node.nil?
        step.mark_waiting!
        handler = WaitHandlers.for(error.type).new(@state)
        handler.pause!(error)
      rescue => pause_error
        fail!(pause_error)
      end

      def create_terminal(status)
        now = Time.current
        DiscourseWorkflows::Execution.create!(
          workflow: @state.workflow,
          trigger_node_id: @state.trigger_node_id,
          status: status,
          trigger_data: @state.trigger_data,
          execution_mode: @options.execution_mode,
          started_at: now,
          finished_at: now,
        )
      end

      private

      def save!
        @state.save!(max_size: MAX_EXECUTION_DATA_SIZE)
      end

      def compute_run_time_ms
        steps = @state.run_data.values.flat_map { |s| Array(s) }
        Execution.compute_run_time_ms(steps)
      end

      def error_handler
        @error_handler ||=
          ErrorHandler.new(
            @state.workflow,
            @state,
            error_depth: @options.error_depth,
            execution_mode: @options.execution_mode,
          )
      end

      def form_triggered?
        @snapshot&.find_node(@state.trigger_node_id)&.type == "trigger:form"
      end

      def publish_form_completion
        message = {
          status: "success",
          form_completion: @state.context["__form_completion"].presence,
        }.compact
        MessageBus.publish(form_channel, message)
      end

      def publish_form_status(status)
        MessageBus.publish(form_channel, { status: status })
      end

      def form_channel
        Executor.form_channel(@state.execution.id)
      end
    end
  end
end
