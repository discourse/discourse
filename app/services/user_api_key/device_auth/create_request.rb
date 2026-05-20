# frozen_string_literal: true

class UserApiKey::DeviceAuth::CreateRequest
  include Service::Base

  params do
    attribute :nonce, :string
    attribute :scopes, :string
    attribute :client_id, :string
    attribute :application_name, :string
    attribute :public_key, :string
    attribute :push_url, :string
    attribute :padding, :string
    attribute :expires_in_seconds, :string

    validates :nonce, presence: true
    validates :scopes, presence: true
    validates :client_id, presence: true
  end

  model :client, optional: true

  try Discourse::InvalidParameters, Discourse::InvalidAccess do
    step :validate_request
    step :build_grant
    step :validate_grant_size
    step :reserve_codes
    step :store_grant
  end

  private

  def fetch_client(params:)
    UserApiKeyClient.find_by(client_id: params.client_id)
  end

  def validate_request(params:, client:)
    UserApiKey::DeviceAuth.validate_request!(params.attributes.symbolize_keys, client)
  end

  def build_grant(params:, client:)
    request_params = params.attributes.symbolize_keys
    scopes = request_params[:scopes].split(",")
    expires_in_seconds =
      UserApiKey::DeviceAuth.parse_expires_in_seconds!(request_params[:expires_in_seconds])
    device_code = SecureRandom.hex(32)

    context[:device_request] = { device_code: device_code }
    context[:grant] = UserApiKey::DeviceAuth.build_grant(
      request_params,
      client,
      scopes,
      expires_in_seconds,
      device_code,
    )
    UserApiKey::DeviceAuth.validate_payload_size!(context[:grant])
  end

  def validate_grant_size(grant:)
    UserApiKey::DeviceAuth.validate_grant_size!(grant)
  end

  def reserve_codes(device_request:, grant:)
    request_token = nil
    user_code = nil

    begin
      request_token =
        UserApiKey::DeviceAuth::Store.reserve_request_token!(device_request[:device_code])
      user_code = UserApiKey::DeviceAuth::Store.reserve_user_code!(device_request[:device_code])

      grant["user_code"] = user_code
      grant["request_token"] = request_token
      device_request[:user_code] = user_code
      device_request[:request_token] = request_token
    rescue StandardError
      if request_token.present?
        Discourse.redis.del(UserApiKey::DeviceAuth::Store.device_request_key(request_token))
      end
      if user_code.present?
        Discourse.redis.del(UserApiKey::DeviceAuth::Store.device_user_code_key(user_code))
      end
      raise
    end
  end

  def store_grant(device_request:, grant:)
    UserApiKey::DeviceAuth.validate_grant_size!(grant)
    UserApiKey::DeviceAuth::Store.save!(
      device_request[:device_code],
      grant,
      ttl: UserApiKey::DeviceAuth::DEVICE_AUTH_TTL,
    )
  end
end
