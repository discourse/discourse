# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::ExpireWaiting
    include Service::Base

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    step :expire_executions

    private

    def expire_executions
      DiscourseWorkflows::Execution.expired_waiting.find_each do |execution|
        timeout_action = execution.waiting_config&.dig("timeout_action")

        if timeout_action == "fail"
          execution.fail_with_timeout!
        else
          response_items = [{ "json" => { "approved" => false, "timed_out" => true } }]
          DiscourseWorkflows::Executor.resume(execution, response_items)
        end
      end
    end
  end
end
