# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::CheckSchedules
    include Service::Base

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    model :schedule_triggers
    step :process_schedules

    private

    def fetch_schedule_triggers
      DiscourseWorkflows::Node.enabled_triggers(:schedule)
    end

    def process_schedules(schedule_triggers:)
      now = Time.current.utc

      schedule_triggers.find_each do |node|
        cron = node.configuration&.dig("cron")
        next unless DiscourseWorkflows::CronParser.matches?(cron, now)
        next if node.triggered_this_minute?(now)

        Jobs.enqueue(
          Jobs::DiscourseWorkflows::ExecuteWorkflow,
          trigger_node_id: node.id,
          trigger_data: DiscourseWorkflows::Triggers::Schedule::V1.new.output,
        )

        node.mark_triggered!(now)
      end
    end
  end
end
