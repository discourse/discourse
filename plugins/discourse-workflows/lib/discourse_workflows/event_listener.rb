# frozen_string_literal: true

module DiscourseWorkflows
  class EventListener
    def self.handle(trigger_class, *args)
      return unless SiteSetting.discourse_workflows_enabled

      trigger = trigger_class.new(*args)
      return unless trigger.valid?

      db = RailsMultisite::ConnectionManagement.current_db
      chain = (DiscourseWorkflows::CurrentExecution.workflow_execution_chains || {})[db] || []

      DiscourseWorkflows::WorkflowDependency
        .enabled_trigger_entries(trigger_class.identifier)
        .each do |entry|
          next if chain.include?(entry[:workflow_id])

          Jobs.enqueue(
            Jobs::DiscourseWorkflows::ExecuteWorkflow,
            workflow_id: entry[:workflow_id],
            trigger_node_id: entry[:node_id],
            trigger_data: trigger.output,
            workflow_execution_chain: chain,
          )
        rescue => e
          Rails.logger.error(
            "discourse-workflows: trigger #{trigger_class.identifier} failed " \
              "for workflow #{entry[:workflow_id]}: #{e.message}",
          )
        end
    end
  end
end
