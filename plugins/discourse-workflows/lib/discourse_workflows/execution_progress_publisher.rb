# frozen_string_literal: true

module DiscourseWorkflows
  class ExecutionProgressPublisher
    EXECUTIONS_CHANNEL = "/discourse-workflows/executions"
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

    class << self
      def execution_channel(execution_id)
        "/discourse-workflows/execution/#{execution_id}"
      end

      def publish_created(execution, workflow_name:)
        MessageBus.publish(
          EXECUTIONS_CHANNEL,
          {
            type: "execution_created",
            execution: execution_summary(execution, workflow_name: workflow_name),
          },
          **publish_options,
        )
      end

      def publish(execution, step: nil, refresh: false)
        payload = {
          type: "execution_progress",
          execution: execution_progress(execution),
          refresh: refresh,
        }
        payload[:step] = step.to_h.slice(*STEP_FIELDS).merge("error" => step.error) if step

        MessageBus.publish(execution_channel(execution.id), payload, **publish_options)
        publish_list_update(execution) unless step
      end

      def publish_list_update(execution)
        MessageBus.publish(
          EXECUTIONS_CHANNEL,
          {
            type: "execution_update",
            execution: execution_summary(execution).except(:workflow_name),
          },
          **publish_options,
        )
      end

      def execution_progress(execution)
        {
          id: execution.id,
          status: execution.status,
          error: execution.error,
          run_time_ms: execution.run_time_ms,
          started_at: execution.started_at,
          finished_at: execution.finished_at,
        }
      end
    end
    private_class_method :execution_progress

    class << self
      def execution_summary(execution, workflow_name: nil)
        {
          id: execution.id,
          workflow_id: execution.workflow_id,
          workflow_name: workflow_name,
          status: execution.status,
          error: execution.error,
          run_time_ms: execution.run_time_ms,
          started_at: execution.started_at,
          finished_at: execution.finished_at,
          created_at: execution.created_at,
        }
      end
    end
    private_class_method :execution_summary

    class << self
      def publish_options
        {
          group_ids: [Group::AUTO_GROUPS[:admins]],
          max_backlog_age: MAX_BACKLOG_AGE,
          max_backlog_size: MAX_BACKLOG_SIZE,
        }
      end
    end
    private_class_method :publish_options
  end
end
