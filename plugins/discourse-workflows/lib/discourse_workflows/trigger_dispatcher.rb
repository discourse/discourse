# frozen_string_literal: true

module DiscourseWorkflows
  class TriggerDispatcher
    def self.enqueue(
      published_trigger,
      trigger_data:,
      user_id: nil,
      run_at: nil,
      post_button_feedback: nil
    )
      args = {
        workflow_id: published_trigger.workflow_id,
        workflow_version_id: published_trigger.workflow_version_id,
        trigger_node_id: published_trigger.trigger_node_id,
        trigger_data: trigger_data,
      }
      args[:user_id] = user_id if user_id
      args[:post_button_feedback] = post_button_feedback if post_button_feedback

      if run_at.present? && run_at > Time.current
        return Jobs.enqueue_at(run_at, Jobs::DiscourseWorkflows::ExecuteWorkflow, args)
      end

      Jobs.enqueue(Jobs::DiscourseWorkflows::ExecuteWorkflow, args)
    end

    # A draft trigger runs as a manual execution of the unpublished graph.
    def self.execute(trigger, trigger_data:, user: nil, webhook_context: nil, job_id: nil)
      options =
        DiscourseWorkflows::Executor::ExecutionOptions.new(
          user:,
          execution_mode: trigger.draft? ? :manual : :normal,
          draft_execution: trigger.draft?,
          workflow_version: trigger.workflow_version,
          webhook_context:,
          job_id:,
        )

      DiscourseWorkflows::Executor.new(
        trigger.workflow,
        trigger.trigger_node_id,
        trigger_data,
        options,
      ).run
    end
  end
end
