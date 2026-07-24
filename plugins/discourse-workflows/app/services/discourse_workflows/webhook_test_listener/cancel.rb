# frozen_string_literal: true

module DiscourseWorkflows
  class WebhookTestListener::Cancel
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :listener_id, :string

      validates :workflow_id, presence: true
      validates :listener_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :workflow
    model :listener, :find_webhook_test_listener
    policy :listener_belongs_to_workflow
    policy :owns_webhook_test_listener
    step :cancel_webhook_test_listener

    private

    def fetch_workflow(params:)
      Workflow.find_by(id: params.workflow_id)
    end

    def find_webhook_test_listener(params:)
      WebhookTestListener.find(params.listener_id)
    end

    def listener_belongs_to_workflow(workflow:, listener:)
      listener.workflow_id == workflow.id
    end

    def owns_webhook_test_listener(listener:, guardian:)
      listener.owned_by?(guardian.user)
    end

    def cancel_webhook_test_listener(listener:)
      WebhookTestListener.cancel!(listener)
    end
  end
end
