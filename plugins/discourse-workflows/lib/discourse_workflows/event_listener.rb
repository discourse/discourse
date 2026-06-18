# frozen_string_literal: true

module DiscourseWorkflows
  class EventListener
    def self.handle(trigger_class, *args)
      return unless SiteSetting.discourse_workflows_enabled
      return if WorkflowDependency.active_node_types.exclude?(trigger_class.identifier)

      trigger = trigger_class.new(*args)
      return unless trigger.valid?

      trigger_data = nil

      DiscourseWorkflows::Workflow::Action::FindPublishedTriggers
        .call(
          trigger_type: trigger_class.identifier,
          filter: ->(published_trigger) do
            trigger.matches?(
              DiscourseWorkflows::TriggerNodeContext.from_published_trigger(published_trigger),
            )
          end,
        )
        .each do |published_trigger|
          DiscourseWorkflows::TriggerDispatcher.enqueue(
            published_trigger,
            trigger_data: (trigger_data ||= trigger.output),
          )
        rescue => e
          Rails.logger.error(
            "discourse-workflows: trigger #{trigger_class.identifier} failed " \
              "for workflow #{published_trigger.workflow_id}: #{e.message}",
          )
        end
    end
  end
end
