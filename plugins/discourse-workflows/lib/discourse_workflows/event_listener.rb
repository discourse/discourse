# frozen_string_literal: true

module DiscourseWorkflows
  class EventListener
    def self.handle(trigger_class, *args, event_name: nil)
      return unless SiteSetting.enable_discourse_workflows
      return if WorkflowDependency.active_node_types.exclude?(trigger_class.identifier)

      published_triggers =
        WorkflowDependency
          .cached_published_triggers(trigger_class.identifier)
          .select do |published_trigger|
            NodeData.type_version(published_trigger.trigger_node) == trigger_class.version
          end
      return if published_triggers.empty?

      trigger = trigger_class.from_event(event_name, *args)
      return unless trigger.valid?

      trigger_data = nil
      user_id = trigger.user_id if trigger.respond_to?(:user_id)

      published_triggers.each do |published_trigger|
        next if !trigger.matches?(TriggerNodeContext.from_published_trigger(published_trigger))

        TriggerDispatcher.enqueue(
          published_trigger,
          trigger_data: (trigger_data ||= trigger.output),
          user_id: user_id,
        )
      rescue => e
        Rails.logger.error(
          "discourse-workflows: trigger #{trigger_class.identifier} failed " \
            "for workflow #{published_trigger.workflow_id}: #{e.message}",
        )
      end
    rescue => e
      Rails.logger.error(
        "discourse-workflows: trigger #{trigger_class.identifier} failed: #{e.message}",
      )
    end
  end
end
