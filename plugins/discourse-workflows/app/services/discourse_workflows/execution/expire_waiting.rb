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
          config["timeout_response_items"] || default_response_items(expired_execution)
        Executor.resume(expired_execution, response_items)
      end
    end

    def default_response_items(execution)
      entries = execution.execution_data&.entries || {}
      steps = entries[execution.waiting_node_id.to_s] || []
      waiting_step = steps.find { |s| s["status"] == "waiting" }
      waiting_step&.dig("input") || [{ "json" => {} }]
    end
  end
end
