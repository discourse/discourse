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
    model :published_trigger
    model :topic
    step :enqueue_workflow

    private

    def fetch_published_trigger(params:)
      DiscourseWorkflows::Workflow::Action::FindPublishedTriggers.call(
        trigger_type: "trigger:topic_admin_button",
        filter: ->(published_trigger) do
          published_trigger.trigger_node_id == params.trigger_node_id
        end,
      ).first
    end

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def enqueue_workflow(published_trigger:, topic:, guardian:)
      trigger = DiscourseWorkflows::Nodes::TopicAdminButton::V1.new(topic)
      DiscourseWorkflows::TriggerDispatcher.enqueue(
        published_trigger,
        trigger_data: trigger.output,
        user_id: guardian.user.id,
      )
    end
  end
end
