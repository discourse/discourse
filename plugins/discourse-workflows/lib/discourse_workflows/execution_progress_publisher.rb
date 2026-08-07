# frozen_string_literal: true

module DiscourseWorkflows
  class ExecutionProgressPublisher
    MAX_BACKLOG_AGE = 1.hour.to_i
    MAX_BACKLOG_SIZE = 100

    STEP_FIELDS = %w[
      node_id
      node_name
      node_type
      position
      status
      error
      started_at
      finished_at
    ].freeze

    def self.publish(execution, step: nil, refresh: false)
      payload = {
        type: "execution_progress",
        execution: {
          id: execution.id,
          status: execution.status,
          error: execution.error,
          run_time_ms: execution.run_time_ms,
          started_at: execution.started_at,
          finished_at: execution.finished_at,
        },
        refresh: refresh,
      }
      payload[:step] = step.to_h.slice(*STEP_FIELDS).merge("error" => step.error) if step

      MessageBus.publish(
        "/discourse-workflows/execution/#{execution.id}",
        payload,
        group_ids: [Group::AUTO_GROUPS[:admins]],
        max_backlog_age: MAX_BACKLOG_AGE,
        max_backlog_size: MAX_BACKLOG_SIZE,
      )
    end
  end
end
