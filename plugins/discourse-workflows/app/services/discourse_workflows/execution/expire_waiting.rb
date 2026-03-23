# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::ExpireWaiting
    include Service::Base

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    step :expire_executions

    private

    def expire_executions
      expired_executions.find_each do |execution|
        timeout_action = execution.waiting_config&.dig("timeout_action")

        if timeout_action == "fail"
          fail_execution(execution)
        else
          deny_execution(execution)
        end
      end
    end

    def fail_execution(execution)
      error_message = I18n.t("discourse_workflows.errors.approval_timed_out")

      execution.update!(
        status: :error,
        error: error_message,
        finished_at: Time.current,
        waiting_node_id: nil,
        waiting_until: nil,
        waiting_config: {
        },
      )

      waiting_step = execution.steps.find_by(status: :waiting)
      waiting_step&.update!(status: :error, error: error_message, finished_at: Time.current)
    end

    def deny_execution(execution)
      response_items = [{ "json" => { "approved" => false, "timed_out" => true } }]
      DiscourseWorkflows::Executor.resume(execution, response_items)
    end

    def expired_executions
      DiscourseWorkflows::Execution.where(status: :waiting).where(
        "waiting_until IS NOT NULL AND waiting_until < ?",
        Time.current,
      )
    end
  end
end
