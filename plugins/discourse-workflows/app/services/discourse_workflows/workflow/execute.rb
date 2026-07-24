# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Execute
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :workflow_version_id, :string
      attribute :trigger_node_id, :string
      attribute :trigger_data, default: -> { {} }
      attribute :execution_mode, :string, default: "normal"
      attribute :user_id, :integer

      validates :trigger_node_id, presence: true
    end

    policy :can_execute, class_name: DiscourseWorkflows::Policy::WorkflowsEnabled
    model :workflow
    model :workflow_version
    model :trigger_node
    model :user, optional: true
    model :execution, :run_workflow

    private

    def fetch_workflow(params:)
      if params.workflow_id.present?
        return(
          DiscourseWorkflows::Workflow.includes(:active_version).find_by(id: params.workflow_id)
        )
      end

      DiscourseWorkflows::Workflow
        .published
        .includes(:active_version)
        .joins(:workflow_dependencies)
        .where(discourse_workflows_workflow_dependencies: { node_id: params.trigger_node_id })
        .where(
          "discourse_workflows_workflows.active_version_id = " \
            "discourse_workflows_workflow_dependencies.workflow_version_id",
        )
        .first
    end

    def fetch_workflow_version(workflow:, params:)
      return workflow.active_version if params.workflow_version_id.blank?

      workflow.workflow_versions.find_by(version_id: params.workflow_version_id)
    end

    def fetch_trigger_node(workflow:, workflow_version:, params:)
      workflow.find_node_in(workflow_version.nodes, params.trigger_node_id)
    end

    def fetch_user(params:)
      User.find_by(id: params.user_id) if params.user_id.present?
    end

    def run_workflow(trigger_node:, workflow:, workflow_version:, params:, user:)
      options =
        DiscourseWorkflows::Executor::ExecutionOptions.new(
          user: user,
          execution_mode: params.execution_mode.to_sym,
          workflow_version: workflow_version,
        )
      executor =
        DiscourseWorkflows::Executor.new(workflow, trigger_node["id"], params.trigger_data, options)
      executor.run
      executor.execution
    end
  end
end
