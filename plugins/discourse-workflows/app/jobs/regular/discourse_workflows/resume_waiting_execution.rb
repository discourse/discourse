# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeWaitingExecution < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.enable_discourse_workflows

        execution = ::DiscourseWorkflows::Execution.find_by(id: args[:execution_id])
        return if execution.nil? || !execution.waiting?
        return if execution.waiting_until.present? && execution.waiting_until > Time.current

        if execution.timeout_action == "fail"
          execution.fail_with_timeout!
        else
          claimed = ::DiscourseWorkflows::Execution.claim_for_resume(execution)
          return if claimed.nil?

          ::DiscourseWorkflows::Executor.resume(claimed, claimed.waiting_step_input_items)
        end
      end
    end
  end
end
