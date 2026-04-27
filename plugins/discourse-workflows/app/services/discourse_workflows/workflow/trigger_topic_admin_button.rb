# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::TriggerTopicAdminButton
    include Service::Base

    params do
      attribute :trigger_node_id, :string
      attribute :topic_id, :integer

      validates :trigger_node_id, presence: true
      validates :topic_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :workflow
    model :trigger_node
    model :topic
    step :enqueue_workflow

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::WorkflowDependency
        .enabled_workflows_with_node_type("trigger:topic_admin_button")
        .find { |_, node| node["id"] == params.trigger_node_id }
        &.first
    end

    def fetch_trigger_node(params:, workflow:)
      workflow.find_node(params.trigger_node_id)
    end

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def enqueue_workflow(workflow:, trigger_node:, topic:, guardian:)
      trigger = DiscourseWorkflows::Nodes::TopicAdminButton::V1.new(topic)
      Jobs.enqueue(
        Jobs::DiscourseWorkflows::ExecuteWorkflow,
        workflow_id: workflow.id,
        trigger_node_id: trigger_node["id"],
        trigger_data: trigger.output,
        user_id: guardian.user.id,
      )
    end
  end
end
