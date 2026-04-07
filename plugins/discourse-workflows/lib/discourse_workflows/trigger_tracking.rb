# frozen_string_literal: true

module DiscourseWorkflows
  module TriggerTracking
    module_function

    def triggered_this_minute?(workflow, node_id, now = Time.current.utc)
      data = workflow.node_static_data(node_id)
      last_triggered = data["last_triggered_at"]
      return false unless last_triggered
      Time.parse(last_triggered).beginning_of_minute == now.beginning_of_minute
    end

    def mark_triggered!(workflow, node_id, now = Time.current.utc)
      data = workflow.node_static_data(node_id)
      workflow.update_node_static_data!(node_id, data.merge("last_triggered_at" => now.iso8601))
    end

    def triggered_topic_ids(workflow, node_id)
      workflow.node_static_data(node_id).fetch("triggered_topic_ids", [])
    end

    def replace_triggered_topic_ids!(workflow, node_id, topic_ids)
      workflow.reload
      data = workflow.node_static_data(node_id)
      workflow.update_node_static_data!(node_id, data.merge("triggered_topic_ids" => topic_ids))
    end
  end
end
