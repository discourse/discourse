# frozen_string_literal: true

module DiscourseWorkflows
  class Credential::Update
    include Service::Base

    params do
      attribute :credential_id, :integer
      attribute :name, :string
      attribute :data

      validates :credential_id, presence: true
      validates :name, presence: true
    end

    model :credential
    policy :can_manage_workflows

    model :credential, :save_credential
    step :log_credential_update

    private

    def fetch_credential(params:)
      DiscourseWorkflows::Credential.find_by(id: params.credential_id)
    end

    def can_manage_workflows(guardian:)
      guardian.is_admin?
    end

    def save_credential(credential:, params:)
      credential.name = params.name
      credential.merge_data(params.data.to_h) if params.data.present?
      credential.save
      credential
    end

    def log_credential_update(credential:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_credential_updated",
        subject: credential.name,
      )
    end
  end
end
