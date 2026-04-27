# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Destroy
    include Service::Base

    params do
      attribute :workflow_id, :integer
      validates :workflow_id, presence: true
    end

    model :workflow
    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    transaction do
      step :destroy
      step :log
    end

    step :clear_site_cache

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def destroy(workflow:)
      workflow.destroy!
    end

    def log(workflow:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_workflow_destroyed",
        subject: workflow.name,
        workflow_id: workflow.id,
      )
    end

    def clear_site_cache
      Site.clear_cache
      DiscourseWorkflows::WorkflowDependency.clear_cache!
    end
  end
end
