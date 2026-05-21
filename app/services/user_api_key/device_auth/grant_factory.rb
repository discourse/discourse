# frozen_string_literal: true

class UserApiKey::DeviceAuth::GrantFactory
  def self.build(params, client, scopes, expires_in_seconds, device_code)
    {
      status: "pending",
      device_code: device_code,
      application_name:
        if client.present?
          client.application_name.presence || params[:application_name]
        else
          params[:application_name]
        end,
      client_id: params[:client_id],
      public_key: UserApiKey::DeviceAuth::RequestValidator.public_key_str(params, client),
      nonce: params[:nonce],
      scopes: scopes,
      push_url: params[:push_url].presence,
      padding: params[:padding].presence,
      expires_in_seconds: expires_in_seconds,
      unregistered_client: client.blank? || client.public_key.blank?,
      created_at: Time.zone.now.iso8601,
    }.stringify_keys
  end
end
