# frozen_string_literal: true

module DiscourseWorkflows
  class Credential::Destroy
    include Service::Base

    params do
      attribute :credential_id, :integer
      validates :credential_id, presence: true
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :credential
    model :referencing_workflows, optional: true
    policy :credential_not_in_use

    step :remove_credential

    step :log

    private

    def fetch_credential(params:)
      DiscourseWorkflows::Credential.find_by(id: params.credential_id)
    end

    def fetch_referencing_workflows(credential:)
      workflow_ids =
        DiscourseWorkflows::WorkflowDependency.workflows_referencing(
          "credential_id",
          credential.id,
        ).pluck(:workflow_id)
      DiscourseWorkflows::Workflow
        .where(id: workflow_ids)
        .order(:name)
        .pluck(:id, :name)
        .map { |id, name| { id:, name: } }
    end

    def credential_not_in_use(referencing_workflows:)
      referencing_workflows.blank?
    end

    def remove_credential(credential:)
      credential.destroy!
    end

    def log(credential:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_credential_destroyed",
        subject: credential.name,
      )
    end
  end
end
