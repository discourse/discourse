# frozen_string_literal: true

module DiscourseWorkflows
  class CredentialDataValidator
    def self.call(credential_type:, data:)
      schema = credential_type.property_schema || {}
      normalized = (data || {}).stringify_keys

      schema.each_with_object([]) do |(field_name, field_def), missing|
        next unless field_def[:required]
        missing << field_name.to_s if normalized[field_name.to_s].blank?
      end
    end
  end
end
