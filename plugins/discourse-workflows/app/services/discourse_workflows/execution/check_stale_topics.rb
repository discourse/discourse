# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::CheckStaleTopics
    include Service::Base

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    model :stale_trigger_nodes
    step :process_stale_trigger_nodes

    private

    def fetch_stale_trigger_nodes
      DiscourseWorkflows::Workflow::Action::FindPublishedTriggers.call(
        trigger_type: "trigger:stale_topic",
      )
    end

    def process_stale_trigger_nodes(stale_trigger_nodes:)
      stale_trigger_nodes.each do |published_trigger|
        items =
          DiscourseWorkflows::Nodes::StaleTopic::V1.trigger_data_for(
            DiscourseWorkflows::TriggerNodeContext.from_published_trigger(published_trigger),
          )
        next if items.empty?

        DiscourseWorkflows::TriggerDispatcher.enqueue(published_trigger, trigger_data: items)
      end
    end
  end
end
