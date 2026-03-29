# frozen_string_literal: true

module DiscourseWorkflows
  class Credential::Update
    include Service::Base

    REDACTED = "__REDACTED__"

    params do
      attribute :credential_id, :integer
      attribute :name, :string
      attribute :data

      validates :name, presence: true
    end

    model :credential
    policy :can_manage_workflows

    transaction do
      step :update_credential
      step :log_credential_update
    end

    private

    def fetch_credential(params:)
      DiscourseWorkflows::Credential.find_by(id: params.credential_id)
    end

    def can_manage_workflows(guardian:)
      guardian.is_admin?
    end

    def update_credential(credential:, params:)
      credential.name = params.name

      if params.data.present?
        original = credential.decrypted_data
        incoming = params.data.to_h.stringify_keys

        merged =
          incoming.each_with_object({}) do |(key, value), hash|
            hash[key] = value == REDACTED ? original[key] : value
          end

        credential.decrypted_data = merged
      end

      credential.save!
    end

    def log_credential_update(credential:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_credential_updated",
        subject: credential.name,
      )
    end
  end
end
