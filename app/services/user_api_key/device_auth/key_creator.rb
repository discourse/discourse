# frozen_string_literal: true

class UserApiKey::DeviceAuth::KeyCreator
  def self.create!(grant, user)
    validate_grant!(grant)

    UserApiKey.transaction do
      client = UserApiKeyClient.find_by(client_id: grant.client_id)
      client = UserApiKeyClient.new(client_id: grant.client_id) if client.blank?
      client.application_name = grant.application_name if client.new_record?
      client.save! if client.new_record? || client.changed?

      client.keys.where(user_id: user.id).destroy_all
      client.keys.create!(
        user_id: user.id,
        push_url: grant.push_url,
        expires_at: grant.expires_at,
        scopes: grant.scopes.map { |name| UserApiKeyScope.new(name: name) },
      )
    end
  end

  def self.validate_grant!(grant)
    requested_scopes = Set.new(grant.scopes)
    raise Discourse::InvalidAccess unless UserApiKey.allowed_scopes.superset?(requested_scopes)
    UserApiKey::DeviceAuth::RequestValidator.validate_requested_scopes!(grant.scopes)

    client = UserApiKeyClient.find_by(client_id: grant.client_id)
    UserApiKey::DeviceAuth::RequestValidator.validate_client_scopes!(client, grant.scopes)

    public_key = UserApiKey::DeviceAuth::Crypto.parse_public_key!(grant.public_key)
    UserApiKey::DeviceAuth::RequestValidator.validate_public_key_constraints!(public_key)
    UserApiKey::DeviceAuth::RequestValidator.validate_padding!(grant.padding)
    UserApiKey::DeviceAuth::PayloadBuilder.validate_size!(grant)
    validate_grant_size!(grant)
  end

  def self.validate_grant_size!(grant)
    if grant.to_json.bytesize > UserApiKey::DeviceAuth::MAX_DEVICE_GRANT_BYTES
      raise Discourse::InvalidParameters.new(:base)
    end
  end
end
