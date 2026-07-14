# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    class ExecutionRateLimiter
      def initialize(workflow)
        @workflow = workflow
      end

      def within_limits?
        per_workflow_limiter.performed!(raise_error: false) &&
          global_limiter.performed!(raise_error: false)
      end

      private

      def global_limiter
        RateLimiter.new(
          nil,
          "discourse_workflows_executions",
          SiteSetting.discourse_workflows_max_executions_per_minute,
          1.minute,
          global: true,
        )
      end

      def per_workflow_limiter
        RateLimiter.new(
          nil,
          "discourse_workflows_workflow_#{@workflow.id}",
          SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow,
          1.minute,
        )
      end
    end
  end
end
