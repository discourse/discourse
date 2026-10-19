# frozen_string_literal: true

module Jobs
  module DiscourseWorkflows
    class ResumeWaitingExecution < ::Jobs::Base
      def execute(args)
        return unless SiteSetting.enable_discourse_workflows
        return if args[:resume_token].blank?

        execution =
          ::DiscourseWorkflows::Execution.find_by(
            id: args[:execution_id],
            status: :waiting,
            resume_token: args[:resume_token],
          )
        return if execution.nil?
        return if execution.waiting_until.nil? || execution.waiting_until > Time.current
        return execution.fail_with_timeout! if execution.timeout_action == "fail"

        claimed = ::DiscourseWorkflows::Execution.claim_for_resume(execution)
        return if claimed.nil?

        ::DiscourseWorkflows::Executor.resume(claimed, claimed.waiting_step_input_items)
      end
    end
  end
end
