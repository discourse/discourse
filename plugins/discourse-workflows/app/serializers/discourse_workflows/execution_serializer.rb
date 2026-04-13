# frozen_string_literal: true

module DiscourseWorkflows
  class ExecutionSerializer < ApplicationSerializer
    attributes :id,
               :workflow_id,
               :workflow_name,
               :status,
               :trigger_data,
               :error,
               :run_time_ms,
               :started_at,
               :finished_at,
               :created_at

    attribute :steps

    def workflow_name
      object.workflow&.name
    end

    STEP_FIELDS = %w[
      node_id
      node_name
      node_type
      position
      status
      input
      output
      error
      metadata
      started_at
      finished_at
    ].freeze

    def steps
      return [] unless object.execution_data
      object.execution_data.steps_array.map { |step| step.slice(*STEP_FIELDS).symbolize_keys }
    end
  end
end
