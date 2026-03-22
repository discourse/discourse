# frozen_string_literal: true

module DiscourseWorkflows
  class Stats::Summary
    include Service::Base

    RECENT_PERIOD = 7.days

    params { attribute :workflow_id, :integer }

    model :recent_executions, :fetch_recent_executions, optional: true
    model :stats, :summarize_executions

    private

    def fetch_recent_executions(params:)
      scope = DiscourseWorkflows::Execution.where("created_at >= ?", RECENT_PERIOD.ago)
      scope = scope.where(workflow_id: params.workflow_id) if params.workflow_id
      scope
    end

    def summarize_executions(recent_executions:)
      total = recent_executions.count
      failed = recent_executions.where(status: :error).count
      failure_rate = total > 0 ? (failed.to_f / total * 100).round(1) : 0

      durations =
        recent_executions
          .where.not(started_at: nil, finished_at: nil)
          .where(status: %i[success error])
          .pluck(Arel.sql("EXTRACT(EPOCH FROM (finished_at - started_at))"))

      avg_seconds = durations.any? ? (durations.sum / durations.size).round(1) : 0
      avg_duration = avg_seconds < 1 ? "#{(avg_seconds * 1000).round}ms" : "#{avg_seconds}s"

      { total: total, failed: failed, failure_rate: "#{failure_rate}%", avg_duration: avg_duration }
    end
  end
end
