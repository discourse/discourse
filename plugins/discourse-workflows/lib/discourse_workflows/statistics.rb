# frozen_string_literal: true

module DiscourseWorkflows
  module Statistics
    extend PeriodCountHelper

    class << self
      def total
        { count: Workflow.count }
      end

      def created
        period_counts(Workflow.all, :created_at, count: false)
      end

      def edited
        period_counts(
          WorkflowVersion.where("version_number > 1"),
          :created_at,
          count: false,
        ) { |scope| scope.distinct.count(:workflow_id) }
      end

      def executed
        period_counts(ExecutionStat.all, :date, count: false) do |scope|
          scope.distinct.count(:workflow_id)
        end
      end

      def executions
        period_counts(ExecutionStat.all, :date) { |scope| scope.sum(:total_runs) }
      end
    end
  end
end
