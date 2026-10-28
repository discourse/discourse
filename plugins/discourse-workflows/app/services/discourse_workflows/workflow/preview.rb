# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Preview
    include Service::Base

    TriggerPayload = Data.define(:data)

    params do
      attribute :workflow_id, :integer
      attribute :trigger_node_id, :string

      validates :workflow_id, :trigger_node_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    policy :workflow_tests_enabled, class_name: Policy::WorkflowTestsEnabled
    model :workflow
    model :trigger_node
    model :trigger_payload, :collect_trigger_payload
    model :execution, :enqueue_preview

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_trigger_node(workflow:, params:)
      workflow.find_node(params.trigger_node_id)
    end

    def collect_trigger_payload(workflow:, trigger_node:, guardian:)
      return TriggerPayload.new(data: {}) if workflow.node_pinned?(trigger_node["name"])

      data = TriggerRuntime.collect_payload_for(workflow:, trigger_node:, user: guardian.user)
      TriggerPayload.new(data:) unless data.nil?
    end

    def enqueue_preview(workflow:, trigger_node:, trigger_payload:, guardian:)
      execution =
        Execution.create_pending_simulation!(
          workflow:,
          trigger_node_id: trigger_node["id"],
          trigger_data: trigger_payload.data,
        )
      Jobs.enqueue(
        Jobs::DiscourseWorkflows::RunSimulation,
        execution_id: execution.id,
        user_id: guardian.user.id,
      )
      execution
    end
  end
end
