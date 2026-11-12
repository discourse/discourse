# frozen_string_literal: true

module DiscourseWorkflows
  class CredentialSerializer < ApplicationSerializer
    attributes :id, :name, :credential_type, :data, :data_modes, :created_at, :updated_at

    def data
      schema = Registry.find_credential_type(object.credential_type)&.property_schema || {}
      credential_data.to_h do |key, value|
        [
          key,
          schema.dig(key.to_sym, :ui, :control) == :password ? Credential::REDACTED_VALUE : value,
        ]
      end
    end

    def data_modes
      credential_data.transform_values do |value|
        value.is_a?(String) && value.start_with?("=") ? "expression" : "fixed"
      end
    end

    private

    def credential_data
      @credential_data ||= object.data || {}
    end
  end
end
