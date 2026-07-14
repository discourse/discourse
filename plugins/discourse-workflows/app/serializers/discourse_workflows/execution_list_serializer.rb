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
               :created_at

    def workflow_name
      object.workflow_snapshot_name
    end
  end
end
