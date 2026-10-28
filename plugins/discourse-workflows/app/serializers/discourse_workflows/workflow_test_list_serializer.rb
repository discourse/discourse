# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowTestListSerializer < ApplicationSerializer
    attributes :id,
               :workflow_id,
               :name,
               :state,
               :reason,
               :result_current,
               :captured_at,
               :steps_needing_response,
               :source_execution_id,
               :latest_execution_id,
               :last_run_at,
               :checks_count,
               :updated_at

    def result_current
      object.result_current?
    end

    def last_run_at
      object.latest_execution&.finished_at || object.latest_execution&.created_at
    end

    def checks_count
      object.checks.size
    end
  end
end
