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
        workflow.nodes.each do |node|
          next if node["type"] != "trigger:schedule"

          rules = ScheduleRule.rules_from_configuration(node["configuration"] || {})
          rules.each_with_index do |rule, index|
            next unless ScheduleRule.seconds_rule?(rule)

            ScheduleRule.start_seconds_chain!(workflow, node["id"], index, rule)
          end
        end
      end
    end
  end
end
