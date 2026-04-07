# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::CheckStaleTopics
    include Service::Base

    MAX_TOPICS_PER_CYCLE = 100

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    model :stale_trigger_nodes
    step :process_stale_trigger_nodes

    private

    def fetch_stale_trigger_nodes
      DiscourseWorkflows::Workflow.enabled_trigger_nodes("stale_topic")
    end

    def process_stale_trigger_nodes(stale_trigger_nodes:)
      stale_trigger_nodes.each do |workflow, node|
        hours = (node.dig("configuration", "hours") || 24).to_i.clamp(1..)
        threshold = hours.hours.ago
        triggered_ids =
          Set.new(DiscourseWorkflows::TriggerTracking.triggered_topic_ids(workflow, node["id"]))

        current_stale_ids =
          Topic
            .where("GREATEST(topics.created_at, topics.last_posted_at) < ?", threshold)
            .where(closed: false, archived: false, deleted_at: nil, visible: true)
            .where("topics.archetype = ?", Archetype.default)
            .pluck(:id)

        newly_stale_ids = current_stale_ids.reject { |id| triggered_ids.include?(id) }

        Topic
          .where(id: newly_stale_ids.first(MAX_TOPICS_PER_CYCLE))
          .each do |topic|
            trigger = DiscourseWorkflows::Nodes::StaleTopic::V1.new(topic)

            Jobs.enqueue(
              Jobs::DiscourseWorkflows::ExecuteWorkflow,
              workflow_id: workflow.id,
              trigger_node_id: node["id"],
              trigger_data: trigger.output,
            )
          end

        DiscourseWorkflows::TriggerTracking.replace_triggered_topic_ids!(
          workflow,
          node["id"],
          current_stale_ids,
        )
      end
    end
  end
end
