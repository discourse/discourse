# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class CompletionHandler
      MAX_EXECUTION_DATA_SIZE = 5.megabytes

      attr_writer :snapshot

      def initialize(persistence:, context:, journal:, runtime:, options:)
        @persistence = persistence
        @context = context
        @journal = journal
        @runtime = runtime
        @options = options
        @snapshot = nil
      end

      def finish!
        save!
        @persistence.execution.update!(
          status: :success,
          finished_at: Time.current,
          run_time_ms: compute_run_time_ms,
        )
        publish_form_completion if form_triggered?
        @persistence.execution
      end

      def fail!(error)
        save!
        @persistence.execution.update!(
          status: :error,
          error: error.message.to_s.truncate(1000),
          finished_at: Time.current,
          run_time_ms: compute_run_time_ms,
        )
        publish_form_status("error") if form_triggered?
        error_handler.trigger_error_workflow(error)
        @persistence.execution
      end

      def wait!(error)
        step = @runtime.waiting_step
        node = @runtime.waiting_node
        raise ArgumentError, "waiting step is required to pause execution" if step.nil?
        raise ArgumentError, "waiting node is required to pause execution" if node.nil?
        step.mark_waiting!
        handler =
          WaitHandlers.for(error.type).new(
            persistence: @persistence,
            context: @context,
            runtime: @runtime,
          )
        handler.pause!(error)
      rescue => pause_error
        fail!(pause_error)
      end

      def create_terminal(status)
        now = Time.current
        DiscourseWorkflows::Execution.create!(
          workflow: @persistence.workflow,
          trigger_node_id: @persistence.trigger_node_id,
          status: status,
          trigger_data: @persistence.trigger_data,
          execution_mode: @options.execution_mode,
          started_at: now,
          finished_at: now,
        )
      end

      private

      def save!
        @persistence.save!(max_size: MAX_EXECUTION_DATA_SIZE)
      end

      def compute_run_time_ms
        Execution.compute_run_time_ms(@journal.steps)
      end

      def error_handler
        @error_handler ||=
          ErrorHandler.new(
            @persistence.workflow,
            @journal,
            error_depth: @options.error_depth,
            execution_mode: @options.execution_mode,
          )
      end

      def form_triggered?
        @snapshot&.find_node(@persistence.trigger_node_id)&.type == "trigger:form"
      end

      def publish_form_completion
        message = { status: "success", form_completion: @context.form_completion }.compact
        MessageBus.publish(form_channel, message)
      end

      def publish_form_status(status)
        MessageBus.publish(form_channel, { status: status })
      end

      def form_channel
        Executor.form_channel(@persistence.execution.id)
      end
    end
  end
end
