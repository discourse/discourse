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
      DiscourseWorkflows::WorkflowDependency.enabled_workflows_with_node_type("trigger:stale_topic")
    end

    def process_stale_trigger_nodes(stale_trigger_nodes:)
      stale_trigger_nodes.each do |workflow, node|
        hours = (node.dig("configuration", "hours") || 24).to_i.clamp(1..)
        threshold = hours.hours.ago
        tracked_ids = DiscourseWorkflows::TriggerTracking.triggered_topic_ids(workflow, node["id"])

        newly_stale_topics =
          stale_topics_scope(threshold).where.not(id: tracked_ids).limit(MAX_TOPICS_PER_CYCLE).to_a

        newly_stale_topics.each do |topic|
          trigger = DiscourseWorkflows::Nodes::StaleTopic::V1.new(topic)

          Jobs.enqueue(
            Jobs::DiscourseWorkflows::ExecuteWorkflow,
            workflow_id: workflow.id,
            trigger_node_id: node["id"],
            trigger_data: trigger.output,
          )
        end

        newly_stale_ids = newly_stale_topics.map(&:id)

        still_tracked =
          if tracked_ids.any?
            stale_topics_scope(threshold).where(id: tracked_ids).pluck(:id)
          else
            []
          end

        DiscourseWorkflows::TriggerTracking.replace_triggered_topic_ids!(
          workflow,
          node["id"],
          still_tracked + newly_stale_ids,
        )
      end
    end

    def stale_topics_scope(threshold)
      Topic
        .where("GREATEST(topics.created_at, topics.last_posted_at) < ?", threshold)
        .where(closed: false, archived: false, deleted_at: nil, visible: true)
        .where("topics.archetype = ?", Archetype.default)
    end
  end
end
