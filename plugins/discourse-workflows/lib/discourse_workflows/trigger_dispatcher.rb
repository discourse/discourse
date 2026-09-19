# frozen_string_literal: true

module DiscourseWorkflows
  class TriggerDispatcher
    def self.enqueue(published_trigger, trigger_data:, user_id: nil, run_at: nil)
      args = {
        workflow_id: published_trigger.workflow_id,
        workflow_version_id: published_trigger.workflow_version_id,
        trigger_node_id: published_trigger.trigger_node_id,
        trigger_data: trigger_data,
      }
      args[:user_id] = user_id if user_id

      if run_at.present? && run_at > Time.current
        return Jobs.enqueue_at(run_at, Jobs::DiscourseWorkflows::ExecuteWorkflow, args)
      end

      Jobs.enqueue(Jobs::DiscourseWorkflows::ExecuteWorkflow, args)
    end

    def self.execute(published_trigger, trigger_data:, user: nil, webhook_context: nil)
      options =
        DiscourseWorkflows::Executor::ExecutionOptions.new(
          user: user,
          workflow_version: published_trigger.workflow_version,
          webhook_context: webhook_context,
        )

      DiscourseWorkflows::Executor.new(
        published_trigger.workflow,
        published_trigger.trigger_node_id,
        trigger_data,
        options,
      ).run
    end
  end
end
