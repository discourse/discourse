# frozen_string_literal: true

module DiscourseWorkflows
  class EventListener
    def self.handle(trigger_class, *args)
      return unless SiteSetting.discourse_workflows_enabled

      trigger = trigger_class.new(*args)
      return unless trigger.valid?

      DiscourseWorkflows::Node
        .enabled_of_type(trigger_class.identifier)
        .find_each do |node|
          Jobs.enqueue(
            Jobs::DiscourseWorkflows::ExecuteWorkflow,
            trigger_node_id: node.id,
            trigger_data: trigger.output,
          )
        end
    end
  end
end
