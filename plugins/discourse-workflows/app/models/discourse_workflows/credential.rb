# frozen_string_literal: true

module DiscourseWorkflows
  class Credential < ActiveRecord::Base
    self.table_name = "discourse_workflows_credentials"

    # Wire-format placeholder sent in JSON responses for password fields.
    # Must remain a string since it round-trips through JSON serialization.
    REDACTED_VALUE = "__REDACTED__"

    validates :name, presence: true, length: { maximum: 128 }
    validates :credential_type, presence: true, length: { maximum: 64 }
    validate :data_matches_schema
    validate :oauth_configuration_valid, if: :oauth2?
    before_save :encrypt_oauth_client_secret, if: :oauth2?

    def self.public_data_for(type, incoming)
      incoming = (incoming || {}).stringify_keys
      type_class = Registry.find_credential_type(type, include_disabled_plugins: true)
      return {} unless type_class
      return incoming unless type_class.respond_to?(:oauth_provider)
      incoming.slice(*type_class.property_schema.keys.map(&:to_s))
    end

    def oauth2?
      Registry.find_credential_type(credential_type, include_disabled_plugins: true)&.respond_to?(
        :oauth_provider,
      )
    end

    def oauth_provider
      type = Registry.find_credential_type(credential_type)
      raise Discourse::InvalidAccess unless type.respond_to?(:oauth_provider)
      type.oauth_provider.new(self)
    end

    def public_data
      self.class.public_data_for(credential_type, data)
    end

    def oauth_client_secret
      value = data["client_secret"]
      return value if value.is_a?(String)
      raise Oauth2Provider::Error.new("invalid_configuration") unless value.is_a?(Hash)
      CredentialSecrets.decrypt(value.fetch("encrypted"), purpose: "oauth2-client-secret")
    end

    def oauth_connection
      return {} unless oauth2? && data["_oauth2"].present?
      CredentialSecrets.decrypt(data["_oauth2"], purpose: "oauth2-connection:#{id}") || {}
    end

    def oauth_connection=(connection)
      self.data =
        data.merge(
          "_oauth2" => CredentialSecrets.encrypt(connection, purpose: "oauth2-connection:#{id}"),
        )
    end

    def merge_data(incoming)
      original = data || {}
      self.data =
        original.merge(
          self.class.public_data_for(credential_type, incoming),
        ) { |_key, orig_val, new_val| new_val == REDACTED_VALUE ? orig_val : new_val }
    end

    private

    def oauth_configuration_valid
      oauth_provider.validate_configuration(self)
      %w[client_id client_secret].each do |field|
        value = data[field]
        encrypted_secret =
          field == "client_secret" && persisted? && value.is_a?(Hash) &&
            value == data_in_database[field]
        next if encrypted_secret
        unless value.is_a?(String) && value.present? && value.length <= 4096 &&
                 value != REDACTED_VALUE && !value.start_with?("=")
          errors.add(:data, I18n.t("discourse_workflows.oauth2.errors.invalid_configuration"))
        end
      end
    end

    def encrypt_oauth_client_secret
      return unless data["client_secret"].is_a?(String)
      self.data =
        data.merge(
          "client_secret" => {
            "encrypted" =>
              CredentialSecrets.encrypt(data["client_secret"], purpose: "oauth2-client-secret"),
          },
        )
    end

    def data_matches_schema
      return if credential_type.blank?

      type_class = Registry.find_credential_type(credential_type)
      return if type_class.nil?

      CredentialDataValidator
        .call(credential_type: type_class, data: data)
        .each do |field|
          errors.add(
            :data,
            I18n.t("discourse_workflows.errors.credential.missing_required_field", field: field),
          )
        end
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_credentials
#
#  id              :bigint           not null, primary key
#  credential_type :string(64)       not null
#  data            :jsonb            not null
#  name            :string(128)      not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  created_by_id   :integer
#  updated_by_id   :integer
#
# Indexes
#
#  idx_dwf_credentials_on_created_by_id         (created_by_id)
#  idx_dwf_credentials_on_credential_type       (credential_type)
#  idx_dwf_credentials_on_name_credential_type  (name,credential_type) UNIQUE
#  idx_dwf_credentials_on_updated_by_id         (updated_by_id)
#
