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

    def merge_data(incoming)
      original = data || {}
      self.data =
        original.merge(incoming.stringify_keys) do |_key, orig_val, new_val|
          new_val == REDACTED_VALUE ? orig_val : new_val
        end
    end

    private

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
