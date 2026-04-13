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
      DiscourseWorkflows::Execution.expired_waiting
    end

    def expire_execution(expired_execution:)
      config = expired_execution.waiting_config || {}
      timeout_action = config["timeout_action"]

      if timeout_action == "fail"
        expired_execution.fail_with_timeout!
      else
        response_items =
          config["timeout_response_items"] || expired_execution.waiting_step_input_items
        Executor.resume(expired_execution, response_items)
      end
    end
  end
end
