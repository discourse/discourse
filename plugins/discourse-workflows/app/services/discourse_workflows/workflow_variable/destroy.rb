# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowVariable::Destroy
    include Service::Base

    params do
      attribute :workflow_id, :integer
      attribute :variable_id, :integer

      validates :workflow_id, :variable_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    lock(:workflow_id) do
      model :workflow
      model :variable

      transaction do
        step :destroy_variable
        model :workflow_version, :snapshot_workflow
        step :index_dependencies
      end
    end

    step :log_variable_deletion

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_variable(workflow:, params:)
      workflow.variables.find_by(id: params.variable_id)
    end

    def destroy_variable(variable:)
      variable.destroy!
    end

    def snapshot_workflow(workflow:, guardian:)
      workflow.snapshot!(user: guardian.user)
    end

    def index_dependencies(workflow:, workflow_version:)
      DiscourseWorkflows::WorkflowDependencyIndexer.call(workflow, version: workflow_version)
    end

    def log_variable_deletion(variable:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_workflow_variable_destroyed",
        subject: variable.key,
      )
    end
  end
end
