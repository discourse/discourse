# frozen_string_literal: true

module DiscourseWorkflows
  class ExecutionStepSerializer < ApplicationSerializer
    attributes :id,
               :node_id,
               :node_name,
               :node_type,
               :position,
               :status,
               :input,
               :output,
               :error,
               :metadata,
               :started_at,
               :finished_at
  end
end
