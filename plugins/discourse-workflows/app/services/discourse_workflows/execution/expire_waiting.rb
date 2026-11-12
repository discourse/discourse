# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::ExpireWaiting
    include Service::Base

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    model :expired_executions, optional: true

    each :expired_executions do
      step :expire_execution
    end

    private

    def fetch_expired_executions
      DiscourseWorkflows::Execution.expired_waiting.includes(:execution_data).limit(500)
    end

    def expire_execution(expired_execution:)
      if expired_execution.timeout_action == "fail"
        expired_execution.fail_with_timeout!
      else
        response_items = expired_execution.waiting_step_input_items
        claimed = DiscourseWorkflows::Execution.claim_for_resume(expired_execution)
        return if claimed.nil?

        Executor.resume(claimed, response_items)
      end
    end
  end
end
