# frozen_string_literal: true

module DiscourseWorkflows
  module Statistics
    extend PeriodCountHelper

    def self.total
      { count: Workflow.count }
    end

    def self.created
      period_counts(Workflow.all, :created_at, count: false)
    end

    def self.edited
      period_counts(
        WorkflowVersion.where("version_number > 1"),
        :created_at,
        count: false,
      ) { |scope| scope.distinct.count(:workflow_id) }
    end

    def self.executed
      period_counts(ExecutionStat.all, :date, count: false) do |scope|
        scope.distinct.count(:workflow_id)
      end
    end

    def self.executions
      period_counts(ExecutionStat.all, :date) { |scope| scope.sum(:total_runs) }
    end
  end
end
