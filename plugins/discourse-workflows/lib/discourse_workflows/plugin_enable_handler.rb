# frozen_string_literal: true

module DiscourseWorkflows
  module PluginEnableHandler
    module_function

    def handle!
      reschedule_waiting_executions!
      restart_seconds_chains!
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

    def restart_seconds_chains!
      Workflow.enabled.find_each do |workflow|
        workflow.each_seconds_schedule_rule do |node, rule, rule_index|
          ScheduleRule.start_seconds_chain!(workflow, node["id"], rule_index, rule)
        end
      end
    end
  end
end
