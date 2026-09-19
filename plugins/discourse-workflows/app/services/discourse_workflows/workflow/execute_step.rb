# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::ExecuteStep
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :node_id, :string

      validates :node_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :workflow
    model :workflow_snapshot
    model :step_node
    policy :step_node_executable
    policy :step_node_not_waiting
    model :source_execution, optional: true
    model :source_run_data, optional: true
    model :execution_plan
    policy :step_data_reachable
    policy :execution_path_not_waiting
    model :trigger_data, optional: true
    model :execution, :create_execution
    step :enqueue_execution

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_workflow_snapshot(workflow:)
      DiscourseWorkflows::WorkflowSnapshot.from_workflow(workflow, published: false)
    end

    def fetch_step_node(workflow_snapshot:, params:)
      workflow_snapshot.find_node(params.node_id)
    end

    def step_node_executable(step_node:)
      return false if step_node.type.to_s.start_with?("trigger:")

      node_type_class =
        DiscourseWorkflows::Registry.find_node_type(step_node.type, version: step_node.type_version)
      node_type_class.present? && node_type_class.available?
    end

    def step_node_not_waiting(step_node:)
      DiscourseWorkflows::NodeType.waiting_identifiers.exclude?(step_node.type)
    end

    def fetch_source_execution(workflow:)
      workflow.executions.successful.includes(:execution_data).order(created_at: :desc).first
    end

    def fetch_source_run_data(source_execution:)
      source_execution&.execution_data&.run_data || {}
    end

    def fetch_execution_plan(workflow_snapshot:, step_node:, source_run_data:)
      DiscourseWorkflows::StepExecutionPlan.new(
        snapshot: workflow_snapshot,
        target: step_node,
        run_data: source_run_data,
      )
    end

    def step_data_reachable(execution_plan:)
      execution_plan.target_reachable?
    end

    def execution_path_not_waiting(execution_plan:)
      waiting_identifiers = DiscourseWorkflows::NodeType.waiting_identifiers
      execution_plan.executable_nodes.none? { |node| waiting_identifiers.include?(node.type) }
    end

    def fetch_trigger_data(execution_plan:, workflow:, source_execution:, guardian:)
      trigger_root = execution_plan.trigger_roots_to_run.first
      if trigger_root
        DiscourseWorkflows::TriggerRuntime.manual_payload_for(
          workflow: workflow,
          trigger_node: trigger_root.to_workflow_node,
          user: guardian.user,
        )
      else
        source_execution&.trigger_data || {}
      end
    end

    def create_execution(workflow:, step_node:, source_run_data:, trigger_data:)
      DiscourseWorkflows::Execution.create_pending_step!(
        workflow: workflow,
        node_id: step_node.id,
        trigger_data: trigger_data || {},
        run_data: source_run_data,
      )
    end

    def enqueue_execution(execution:, step_node:, guardian:)
      Jobs.enqueue(
        Jobs::DiscourseWorkflows::ExecuteManualWorkflow,
        execution_id: execution.id,
        user_id: guardian.user.id,
        step_node_id: step_node.id,
      )
    end
  end
end
