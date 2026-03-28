# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::ExpireWaiting
    include Service::Base

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    model :expired_executions
    step :process_expired_executions

    private

    def fetch_expired_executions
      DiscourseWorkflows::Execution.expired_waiting
    end

    def process_expired_executions(expired_executions:)
      expired_executions.find_each do |execution|
        timeout_action = execution.waiting_config&.dig("timeout_action")
        wait_type = execution.waiting_config&.dig("wait_type")

        if timeout_action == "fail"
          execution.fail_with_timeout!
        elsif wait_type == "timer"
          waiting_step =
            execution.steps.find_by(node_id: execution.waiting_node_id, status: :waiting)
          input_items = waiting_step&.input || [{ "json" => {} }]
          DiscourseWorkflows::Executor.resume(execution, input_items)
        else
          DiscourseWorkflows::Executor.resume(
            execution,
            [{ "json" => { "approved" => false, "timed_out" => true } }],
          )
        end
      end
    end
  end
end
