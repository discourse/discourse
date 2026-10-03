# frozen_string_literal: true

module DiscourseWorkflows
  class CredentialSerializer < ApplicationSerializer
    attributes :id, :name, :credential_type, :data, :data_modes, :created_at, :updated_at

    attributes :oauth_connection, :display_name

    def include_oauth_connection?
      object.oauth2?
    end

    def oauth_connection
      connection = object.oauth_connection
      details = object.oauth_provider.connection_details
      connection
        .slice("status", "last_refreshed_at")
        .reverse_merge("status" => "not_connected")
        .merge("details" => details)
    rescue Discourse::InvalidAccess
      { "status" => "reconnect_required", "details" => [] }
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      { "status" => "reconnect_required" }
    end

    def display_name
      Registry.find_credential_type(
        object.credential_type,
        include_disabled_plugins: true,
      )&.display_name || object.credential_type
    end

    def data
      schema =
        Registry.find_credential_type(
          object.credential_type,
          include_disabled_plugins: true,
        )&.property_schema || {}
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
      @credential_data ||= object.public_data
    end
  end
end
