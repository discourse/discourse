# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::ManualExecute
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :trigger_node_id, :string
      attribute :trigger_data, default: -> { {} }
      attribute :user_id, :integer

      validates :trigger_node_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :workflow
    model :trigger_node
    model :execution, :enqueue_workflow

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_trigger_node(workflow:, params:)
      workflow.find_node(params.trigger_node_id)
    end

    def enqueue_workflow(workflow:, trigger_node:, params:, guardian:)
      execution =
        DiscourseWorkflows::Execution.create_pending_manual!(
          workflow: workflow,
          trigger_node_id: params.trigger_node_id,
          trigger_data: trigger_data(workflow:, trigger_node:, params:, user: guardian.user),
        )
      Jobs.enqueue(
        Jobs::DiscourseWorkflows::ExecuteManualWorkflow,
        execution_id: execution.id,
        user_id: guardian.user.id,
      )
      execution
    end

    def trigger_data(workflow:, trigger_node:, params:, user:)
      return params.trigger_data if params.trigger_data.present?
      return {} if workflow.node_pinned?(trigger_node["name"])
      return {} if trigger_node["type"] == "trigger:manual"

      node_type_class = node_type_for(trigger_node)

      if node_type_class.respond_to?(:trigger_data_for)
        return(
          node_type_class.trigger_data_for(DiscourseWorkflows::TriggerNodeContext.new(trigger_node))
        )
      end

      if node_type_class&.capability_enabled?(:synthesizes_manual_data)
        return TriggerRuntime.manual_trigger_data(workflow:, trigger_node:, user:)
      end

      {}
    end

    def node_type_for(trigger_node)
      DiscourseWorkflows::Registry.find_node_type(
        trigger_node["type"],
        version: trigger_node["typeVersion"],
      )
    end
  end
end
