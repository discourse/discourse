# frozen_string_literal: true

module DiscourseWorkflows
  class ExecutionListSerializer < ApplicationSerializer
    attributes :id,
               :workflow_id,
               :workflow_name,
               :status,
               :error,
               :run_time_ms,
               :started_at,
               :finished_at,
               :created_at,
               :execution_mode,
               :trigger

    def workflow_name
      object[:snapshot_workflow_name].presence || object.workflow.active_version&.name ||
        object.workflow.name
    end

    def trigger
      DiscourseWorkflows::Execution.trigger_summary(
        object[:snapshot_trigger_node] ||
          object.workflow.find_published_node(object.trigger_node_id),
      )
    end
  end
end
