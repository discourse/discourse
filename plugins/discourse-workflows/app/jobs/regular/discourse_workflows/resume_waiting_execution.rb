# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeWaitingExecution < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.discourse_workflows_enabled

        execution =
          ::DiscourseWorkflows::Execution
            .includes(:execution_data)
            .where(id: args[:execution_id], status: :waiting)
            .lock("FOR UPDATE SKIP LOCKED")
            .first
        return if execution.nil?
        return if execution.waiting_until.present? && execution.waiting_until > Time.current

        if execution.timeout_action == "fail"
          execution.fail_with_timeout!
        else
          ::DiscourseWorkflows::Executor.resume(execution, execution.waiting_step_input_items)
        end
      end
    end
  end
end
