# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::TriggerTopicAdminButton
    include Service::Base

    params do
      attribute :trigger_node_id, :integer
      attribute :topic_id, :integer

      validates :trigger_node_id, presence: true
      validates :topic_id, presence: true
    end

    policy :allowed_user
    model :trigger_node
    model :topic
    step :enqueue_workflow

    private

    def fetch_trigger_node(params:)
      DiscourseWorkflows::Node.enabled_of_type("trigger:topic_admin_button").find_by(
        id: params.trigger_node_id,
      )
    end

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def allowed_user(guardian:)
      guardian.is_admin?
    end

    def enqueue_workflow(trigger_node:, topic:)
      trigger = DiscourseWorkflows::Triggers::TopicAdminButton::V1.new(topic)
      Jobs.enqueue(
        Jobs::DiscourseWorkflows::ExecuteWorkflow,
        trigger_node_id: trigger_node.id,
        trigger_data: trigger.output,
      )
    end
  end
end
