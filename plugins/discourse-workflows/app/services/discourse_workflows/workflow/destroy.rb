# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Destroy
    include Service::Base

    params do
      attribute :workflow_id, :integer
      validates :workflow_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :workflow

    transaction { step :delete_workflow }

    step :log
    step :expire_workflow_caches

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def delete_workflow(workflow:)
      workflow.destroy!
    end

    def log(workflow:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_workflow_destroyed",
        subject: workflow.name,
        workflow_id: workflow.id,
      )
    end

    def expire_workflow_caches
      Site.clear_cache
      DiscourseWorkflows::WorkflowDependency.clear_cache!
    end
  end
end
