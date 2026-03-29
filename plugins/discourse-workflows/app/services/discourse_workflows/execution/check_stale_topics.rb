# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::CheckStaleTopics
    include Service::Base

    MAX_TOPICS_PER_CYCLE = 100

    policy :workflows_enabled, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    model :stale_trigger_nodes
    step :process_stale_topics

    private

    def fetch_stale_trigger_nodes
      DiscourseWorkflows::Node.enabled_triggers(:stale_topic)
    end

    def process_stale_topics(stale_trigger_nodes:)
      stale_trigger_nodes.find_each do |node|
        hours = (node.configuration&.dig("hours") || 24).to_i.clamp(1..)
        threshold = hours.hours.ago
        triggered_ids = Set.new(node.triggered_topic_ids)

        current_stale_ids = []
        newly_stale_ids = []

        Topic
          .where("GREATEST(topics.created_at, topics.last_posted_at) < ?", threshold)
          .where(closed: false, archived: false, deleted_at: nil, visible: true)
          .where("topics.archetype = ?", Archetype.default)
          .includes(:tags)
          .find_each do |topic|
            current_stale_ids << topic.id
            newly_stale_ids << topic.id if triggered_ids.exclude?(topic.id)
          end

        newly_stale_ids
          .first(MAX_TOPICS_PER_CYCLE)
          .each do |topic_id|
            topic = Topic.find_by(id: topic_id)
            next unless topic

            trigger = DiscourseWorkflows::Triggers::StaleTopic::V1.new(topic)

            Jobs.enqueue(
              Jobs::DiscourseWorkflows::ExecuteWorkflow,
              trigger_node_id: node.id,
              trigger_data: trigger.output,
            )
          end

        node.replace_triggered_topic_ids!(current_stale_ids)
      end
    end
  end
end
