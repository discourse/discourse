# frozen_string_literal: true

module DiscourseWorkflows
  class Credential::Update
    include Service::Base

    params do
      attribute :credential_id, :integer
      attribute :name, :string
      attribute :data

      validates :credential_id, presence: true
      validates :name, presence: true, length: { maximum: 128 }
      validate :data_must_be_hash

      def data_must_be_hash
        return if data.nil?
        errors.add(:data, :invalid) unless data.is_a?(Hash)
      end
    end

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :credential

    model :credential, :save_credential
    step :log_credential_update

    private

    def fetch_credential(params:)
      DiscourseWorkflows::Credential.find_by(id: params.credential_id)
    end

    def save_credential(credential:, params:)
      credential.name = params.name
      credential.merge_data(params.data) if params.data.present?
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
