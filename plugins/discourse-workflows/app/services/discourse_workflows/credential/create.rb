# frozen_string_literal: true

module DiscourseWorkflows
  class Credential::Create
    include Service::Base

    policy :can_manage_workflows

    params do
      attribute :name, :string
      attribute :credential_type, :string
      attribute :data

      validates :name, presence: true
      validates :credential_type, presence: true
    end

    policy :valid_credential_type
    model :credential, :create_credential
    step :log_credential_creation

    private

    def can_manage_workflows(guardian:)
      guardian.is_admin?
    end

    def valid_credential_type(params:)
      Registry.find_credential_type(params.credential_type).present?
    end

    def create_credential(params:)
      credential =
        DiscourseWorkflows::Credential.new(
          name: params.name,
          credential_type: params.credential_type,
        )
      credential.decrypted_data = params.data.to_h.stringify_keys
      credential.save
      credential.persisted? ? credential : nil
    end

    def log_credential_creation(credential:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_credential_created",
        subject: credential.name,
      )
    end
  end
end
