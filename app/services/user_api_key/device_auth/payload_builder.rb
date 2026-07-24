# frozen_string_literal: true

class UserApiKey::DeviceAuth::PayloadBuilder
  AUTH_API_VERSION = UserApiKey::DeviceAuth::AUTH_API_VERSION
  DEVICE_KEY_PLACEHOLDER = UserApiKey::DeviceAuth::DEVICE_KEY_PLACEHOLDER

  def self.validate_size!(grant)
    payload = payload_json(grant, key_value: DEVICE_KEY_PLACEHOLDER, push: false)
    UserApiKey::DeviceAuth::Crypto.validate_payload_size!(
      payload,
      UserApiKey::DeviceAuth::Crypto.parse_public_key!(grant.public_key),
      padding: grant.padding,
    )
  end

  def self.encrypted_payload!(grant, key)
    public_key = UserApiKey::DeviceAuth::Crypto.parse_public_key!(grant.public_key)
    payload =
      payload_json(grant, key_value: key.key, push: key.has_push?, expires_at: key.expires_at)

    UserApiKey::DeviceAuth::Crypto.validate_payload_size!(
      payload,
      public_key,
      padding: grant.padding,
    )
    Base64.encode64(
      UserApiKey::DeviceAuth::Crypto.encrypt!(public_key, payload, padding: grant.padding),
    )
  end

  def self.payload_json(grant, key_value:, push:, expires_at: grant.expires_at)
    payload = { key: key_value, nonce: grant.nonce, push: push, api: AUTH_API_VERSION }
    payload[:expires_at] = expires_at.iso8601 if expires_at.present?
    payload.to_json
  end
end
