# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTestSerializer < WorkflowTestListSerializer
    attributes :trigger_node_id,
               :trigger_type,
               :trigger_data,
               :checks,
               :pasted_responses,
               :replay_steps,
               :latest_result,
               :created_at

    def latest_result
      execution = object.latest_execution
      return if execution.nil? || object.running?

      simulation = execution.execution_data&.simulation || {}
      {
        execution_id: execution.id,
        status: object.state,
        reason: object.reason,
        checks: object.result&.dig("checks") || [],
        effects: simulation["effects"] || [],
        total_effect_count: simulation["total_effect_count"] || 0,
        truncation_reasons: simulation["truncation_reasons"] || [],
        error_kind: simulation["error_kind"],
        failed_step: simulation["failed_step"],
        pinned_at: simulation["pinned_at"],
        finished_at: execution.finished_at,
      }
    end
  end
end
