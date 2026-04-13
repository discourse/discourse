# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::CheckSchedules
    include Service::Base

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    model :schedule_triggers
    step :fire_due_triggers
    step :restart_stalled_seconds_chains

    private

    def fetch_schedule_triggers
      DiscourseWorkflows::WorkflowDependency.enabled_workflows_with_node_type("trigger:schedule")
    end

    def fire_due_triggers(schedule_triggers:)
      now = Time.current.utc

      schedule_triggers.each do |workflow, node|
        ScheduleRule.fire_matching_trigger!(workflow, node, now)
      end
    end

    def restart_stalled_seconds_chains(schedule_triggers:)
      now = Time.current.utc

      schedule_triggers.each do |workflow, node|
        ScheduleRule.restart_stalled_chains!(workflow, node, now)
      end
    end
  end
end
