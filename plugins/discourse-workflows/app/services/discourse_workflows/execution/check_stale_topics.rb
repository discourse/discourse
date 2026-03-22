# frozen_string_literal: true

module DiscourseWorkflows
  class Execution::CheckStaleTopics
    include Service::Base

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
        triggered_ids = Set.new(node.static_data["triggered_topic_ids"] || [])

        new_topic_ids = []

        stale_topics(threshold).find_each do |topic|
          next if triggered_ids.include?(topic.id)

          trigger = DiscourseWorkflows::Triggers::StaleTopic.new(topic)

          Jobs.enqueue(
            Jobs::DiscourseWorkflows::ExecuteWorkflow,
            trigger_node_id: node.id,
            trigger_data: trigger.output,
          )

          new_topic_ids << topic.id
        end

        next if new_topic_ids.blank?

        node.reload
        merged_ids =
          Set.new(node.static_data["triggered_topic_ids"] || []).merge(new_topic_ids).to_a
        node.update!(static_data: node.static_data.merge("triggered_topic_ids" => merged_ids))
      end
    end

    def stale_topics(threshold)
      Topic
        .where("GREATEST(topics.created_at, topics.last_posted_at) < ?", threshold)
        .where(closed: false, archived: false, deleted_at: nil, visible: true)
        .where("topics.archetype = ?", Archetype.default)
        .includes(:tags)
    end
  end
end
