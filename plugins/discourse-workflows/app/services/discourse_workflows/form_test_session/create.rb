# frozen_string_literal: true

module DiscourseWorkflows
  class FormTestSession::Create
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
    policy :form_trigger_node
    model :token, :create_form_test_session

    private

    def fetch_workflow(params:)
      Workflow.find_by(id: params.workflow_id)
    end

    def fetch_trigger_node(workflow:, params:)
      workflow.find_node(params.trigger_node_id)
    end

    def form_trigger_node(trigger_node:)
      trigger_node["type"] == NodeDataShape::FORM_TRIGGER_TYPE
    end

    def create_form_test_session(workflow:, trigger_node:, guardian:)
      FormTestSession.create!(
        workflow: workflow,
        user: guardian.user,
        trigger_node_id: trigger_node["id"],
      )
    end
  end
end
