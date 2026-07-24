# frozen_string_literal: true

module DiscourseWorkflows
  class Credential::Create
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows

    params do
      attribute :name, :string
      attribute :credential_type, :string
      attribute :data

      validates :name, presence: true, length: { maximum: 128 }
      validates :credential_type, presence: true, length: { maximum: 64 }
      validate :data_must_be_hash

      def data_must_be_hash
        return if data.nil?
        errors.add(:data, :invalid) unless data.is_a?(Hash)
      end

      def normalized_data
        (data || {}).stringify_keys
      end
    end

    policy :valid_credential_type

    model :credential, :create_credential

    step :log_credential_creation

    private

    def valid_credential_type(params:)
      Registry.find_credential_type(params.credential_type).present?
    end

    def create_credential(params:)
      DiscourseWorkflows::Credential.create(
        name: params.name,
        credential_type: params.credential_type,
        data: params.normalized_data,
      )
    end

    def log_credential_creation(credential:, guardian:)
      StaffActionLogger.new(guardian.user).log_custom(
        "discourse_workflows_credential_created",
        subject: credential.name,
      )
    end
  end
end
