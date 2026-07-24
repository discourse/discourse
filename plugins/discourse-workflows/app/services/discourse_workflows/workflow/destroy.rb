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
    model :referencing_workflows, optional: true
    policy :workflow_not_called_by_other_workflows

    step :delete_workflow
    step :log
    step :expire_workflow_caches

    private

    def fetch_workflow(params:)
      DiscourseWorkflows::Workflow.find_by(id: params.workflow_id)
    end

    def fetch_referencing_workflows(workflow:)
      workflow_ids =
        DiscourseWorkflows::WorkflowDependency
          .workflows_referencing("workflow_call", workflow.id)
          .where.not(workflow_id: workflow.id)
          .pluck(:workflow_id)

      DiscourseWorkflows::Workflow
        .where(id: workflow_ids)
        .order(:name)
        .pluck(:id, :name)
        .map { |id, name| { id:, name: } }
    end

    def workflow_not_called_by_other_workflows(referencing_workflows:)
      referencing_workflows.blank?
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
      Workflow::Action::ExpireCaches.call
    end
  end
end
