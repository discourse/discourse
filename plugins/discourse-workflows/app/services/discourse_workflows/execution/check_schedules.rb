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
        next if already_triggered_this_minute?(node, now)

        Jobs.enqueue(
          Jobs::DiscourseWorkflows::ExecuteWorkflow,
          trigger_node_id: node.id,
          trigger_data: DiscourseWorkflows::Triggers::Schedule::V1.new.output,
        )

        node.update!(static_data: node.static_data.merge("last_triggered_at" => now.iso8601))
      end
    end

    def already_triggered_this_minute?(node, now)
      last_triggered = node.static_data&.dig("last_triggered_at")
      return false if last_triggered.blank?

      Time.parse(last_triggered).beginning_of_minute == now.beginning_of_minute
    end
  end
end
