# frozen_string_literal: true

module DiscourseWorkflows
  class WebhookTestListener::Start
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :trigger_node_id, :string

      validates :workflow_id, presence: true
      validates :trigger_node_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :workflow
    model :trigger_node
    policy :webhook_trigger_node
    model :listener, :start_webhook_test_listener

    private

    def fetch_workflow(params:)
      Workflow.find_by(id: params.workflow_id)
    end

    def fetch_trigger_node(workflow:, params:)
      workflow.find_node(params.trigger_node_id)
    end

    def webhook_trigger_node(trigger_node:)
      trigger_node["type"] == "trigger:webhook"
    end

    def start_webhook_test_listener(workflow:, trigger_node:, guardian:)
      WebhookTestListener.create!(
        workflow: workflow,
        user: guardian.user,
        trigger_node: trigger_node,
      )
    rescue WebhookTestListener::ActiveRouteExists
      fail!(I18n.t("discourse_workflows.errors.webhook_test_listener_active"))
    end
  end
end
