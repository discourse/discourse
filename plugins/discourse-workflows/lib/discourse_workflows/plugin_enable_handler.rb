# frozen_string_literal: true

module DiscourseWorkflows
  module PluginEnableHandler
    module_function

    def handle!
      reschedule_waiting_executions!
      activate_published_triggers!
    end

    def reschedule_waiting_executions!
      Execution
        .where(status: :waiting)
        .where.not(waiting_until: nil)
        .find_each do |execution|
          duration = [execution.waiting_until - Time.current, 0].max
          Jobs.enqueue_in(
            duration,
            Jobs::DiscourseWorkflows::ResumeWaitingExecution,
            execution_id: execution.id,
          )
        end
    end

    def activate_published_triggers!
      Workflow
        .published
        .includes(:active_version)
        .find_each do |workflow|
          TriggerRuntime.activate_workflow!(workflow, workflow_version: workflow.active_version)
        end
    end
  end
end
