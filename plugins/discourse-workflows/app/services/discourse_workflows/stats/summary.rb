# frozen_string_literal: true

module DiscourseWorkflows
  class Stats::Summary
    include Service::Base

    RECENT_PERIOD = 7.days

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params { attribute :workflow_id, :integer }

    model :recent_executions, optional: true
    model :stats, :compute_stats

    private

    def fetch_recent_executions(params:)
      Execution.recent(RECENT_PERIOD).for_workflow(params.workflow_id)
    end

    def compute_stats(recent_executions:)
      total, failed, avg_seconds =
        recent_executions.pick(
          Arel.sql("COUNT(*)"),
          Arel.sql("COUNT(*) FILTER (WHERE status = #{Execution.statuses["error"]})"),
          Arel.sql(
            "ROUND(AVG(EXTRACT(EPOCH FROM (finished_at - started_at))) FILTER (" \
              "WHERE finished_at IS NOT NULL AND started_at IS NOT NULL " \
              "AND status IN (#{[Execution.statuses["success"], Execution.statuses["error"]].join(", ")})" \
              ")::numeric, 1)",
          ),
        )

      avg_seconds = avg_seconds&.to_f || 0
      failure_rate = total > 0 ? (failed.to_f / total * 100).round(1) : 0
      avg_duration = avg_seconds < 1 ? "#{(avg_seconds * 1000).round}ms" : "#{avg_seconds}s"

      { total: total, failed: failed, failure_rate: "#{failure_rate}%", avg_duration: avg_duration }
    end
  end
end
