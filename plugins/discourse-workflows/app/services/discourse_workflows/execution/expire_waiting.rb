# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::ExpireWaiting
    include Service::Base

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    step :expire_executions

    private

    def expire_executions
      DiscourseWorkflows::Execution.expired_waiting.find_each do |execution|
        wait_type = execution.waiting_config&.dig("wait_type")
        timeout_action = execution.waiting_config&.dig("timeout_action")

        if timeout_action == "fail"
          execution.fail_with_timeout!
        elsif wait_type == "timer"
          waiting_step =
            execution.steps.find_by(node_id: execution.waiting_node_id, status: :waiting)
          input_items = waiting_step&.input || [{ "json" => {} }]
          DiscourseWorkflows::Executor.resume(execution, input_items)
        else
          response_items = [{ "json" => { "approved" => false, "timed_out" => true } }]
          DiscourseWorkflows::Executor.resume(execution, response_items)
        end
      end
    end
  end
end
