# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::ExpireStale
    include Service::Base

    GRACE_PERIOD = 10.minutes

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    model :stale_executions, optional: true

    each :stale_executions do
      step :expire_execution
    end

    private

    def fetch_stale_executions
      timeout = SiteSetting.discourse_workflows_run_timeout_minutes.minutes
      DiscourseWorkflows::Execution
        .stale((timeout + GRACE_PERIOD).ago)
        .includes(:execution_data)
        .limit(500)
    end

    def expire_execution(stale_execution:)
      stale_execution.fail_as_stale!
    end
  end
end
