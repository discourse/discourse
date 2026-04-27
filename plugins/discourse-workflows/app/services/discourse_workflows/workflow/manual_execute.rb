# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::ManualExecute
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :trigger_node_id, :string
      attribute :trigger_data, default: -> { {} }
      attribute :execution_mode, :string, default: "normal"
      attribute :error_depth, :integer, default: 0
      attribute :user_id, :integer

      validates :trigger_node_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :workflow
    model :trigger_node
    model :execution, :run_workflow

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_trigger_node(workflow:, params:)
      workflow.find_node(params.trigger_node_id)
    end

    def run_workflow(params:, guardian:)
      Workflow::Execute.call(params: params.to_hash, guardian:).execution
    end
  end
end
