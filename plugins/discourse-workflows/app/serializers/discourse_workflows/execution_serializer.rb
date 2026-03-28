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

    WAITING_NODE_TYPES = %w[action:chat_approval].freeze

    has_many :steps, serializer: DiscourseWorkflows::ExecutionStepSerializer, embed: :objects

    def workflow_name
      object.workflow&.name
    end

    def run_time_ms
      timed_steps =
        object.steps.select do |s|
          s.started_at && s.finished_at && WAITING_NODE_TYPES.exclude?(s.node_type)
        end
      return if timed_steps.empty?
      (timed_steps.sum { |s| s.finished_at - s.started_at } * 1000).round
    end

    def steps
      object.steps.sort_by(&:position)
    end
  end
end
