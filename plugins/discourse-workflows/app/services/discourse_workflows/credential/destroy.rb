# frozen_string_literal: true

module DiscourseWorkflows
  class Credential::Destroy
    include Service::Base

    params { attribute :credential_id, :integer }

    model :credential
    policy :can_manage_workflows
    model :referencing_workflows, optional: true
    policy :not_referenced_by_workflows
    step :log_credential_deletion
    step :destroy_credential

    private

    def fetch_credential(params:)
      DiscourseWorkflows::Credential.find_by(id: params.credential_id)
    end

    def can_manage_workflows(guardian:)
      guardian.is_admin?
    end

    def fetch_referencing_workflows(credential:)
      DiscourseWorkflows::Workflow
        .joins(:nodes)
        .where("discourse_workflows_nodes.configuration->>'credential_id' = ?", credential.id.to_s)
        .distinct
    end

    def not_referenced_by_workflows(referencing_workflows:)
      referencing_workflows.empty?
    end

    def log_credential_deletion(credential:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_credential_destroyed",
        subject: credential.name,
      )
    end

    def destroy_credential(credential:)
      credential.destroy!
    end
  end
end
