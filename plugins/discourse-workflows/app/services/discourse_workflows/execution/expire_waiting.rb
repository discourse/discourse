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
      Executor::WaitHandlers.for_execution(expired_execution).on_timeout(expired_execution)
    end
  end
end
