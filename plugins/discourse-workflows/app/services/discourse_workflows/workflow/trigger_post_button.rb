# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::TriggerPostButton
    include Service::Base

    params do
      attribute :trigger_node_id, :string
      attribute :post_id, :integer

      validates :trigger_node_id, presence: true
      validates :post_id, presence: true
    end

    model :published_trigger
    policy :can_use_post_button
    model :post
    policy :can_see_post
    step :enqueue_workflow

    private

    def fetch_published_trigger(params:)
      DiscourseWorkflows::Workflow::Action::FindPublishedTriggers.call(
        trigger_type: "trigger:post_button",
        filter: ->(published_trigger) do
          published_trigger.trigger_node_id == params.trigger_node_id
        end,
      ).first
    end

    def can_use_post_button(published_trigger:, guardian:)
      DiscourseWorkflows::Nodes::PostButton::V1.available_to?(
        guardian.user,
        NodeData.parameters(published_trigger.trigger_node),
      )
    end

    def fetch_post(params:)
      Post.find_by(id: params.post_id)
    end

    def can_see_post(post:, guardian:)
      guardian.can_see?(post)
    end

    def enqueue_workflow(published_trigger:, post:, guardian:)
      trigger = DiscourseWorkflows::Nodes::PostButton::V1.new(post)
      DiscourseWorkflows::TriggerDispatcher.enqueue(
        published_trigger,
        trigger_data: trigger.output,
        user_id: guardian.user.id,
      )
    end
  end
end
