# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ExecutionRateLimiter
      def initialize(workflow)
        @workflow = workflow
      end

      # Records an execution attempt and returns a translated explanation when
      # it exceeds a limit, or nil when it is allowed.
      def exceeded_limit_message
        if !per_workflow_limiter.performed!(raise_error: false)
          I18n.t("discourse_workflows.errors.rate_limited.per_workflow", count: per_workflow_max)
        elsif !global_limiter.performed!(raise_error: false)
          I18n.t("discourse_workflows.errors.rate_limited.global", count: global_max)
        end
      end

      private

      def global_max
        SiteSetting.discourse_workflows_max_executions_per_minute
      end

      def per_workflow_max
        SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow
      end

      def global_limiter
        RateLimiter.new(nil, "discourse_workflows_executions", global_max, 1.minute, global: true)
      end

      def per_workflow_limiter
        RateLimiter.new(
          nil,
          "discourse_workflows_workflow_#{@workflow.id}",
          per_workflow_max,
          1.minute,
        )
      end
    end
  end
end
