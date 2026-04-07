# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeTimer < ::Jobs::Base
      def execute(args)
        execution =
          ::DiscourseWorkflows::Execution
            .includes(:execution_data)
            .where(id: args[:execution_id], status: :waiting)
            .lock("FOR UPDATE SKIP LOCKED")
            .first
        return if execution.nil?
        unless ::DiscourseWorkflows::Executor::WaitHandlers::Timer.handles_execution?(execution)
          return
        end

        input_items =
          ::DiscourseWorkflows::Executor::WaitHandlers::Timer.waiting_input_items(execution)
        ::DiscourseWorkflows::Executor.resume(execution, input_items)
      end
    end
  end
end
