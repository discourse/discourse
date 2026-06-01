# frozen_string_literal: true

module DiscourseWorkflows
  class CredentialDataValidator
    def self.call(credential_type:, data:)
      schema = credential_type.property_schema || {}
      normalized = (data || {}).stringify_keys

      schema.filter_map do |field_name, field_def|
        field_name.to_s if field_def[:required] && normalized[field_name.to_s].blank?
      end
    end
  end
end
