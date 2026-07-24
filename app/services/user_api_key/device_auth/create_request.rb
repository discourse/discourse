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

  options { attribute :request_id, :string }

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
    UserApiKey::DeviceAuth::RequestValidator.validate!(params.attributes.symbolize_keys, client)
  end

  def build_grant(params:, client:)
    request_params = params.attributes.symbolize_keys
    scopes = request_params[:scopes].split(",")
    expires_in_seconds = UserApiKey::Expiry.parse_seconds!(request_params[:expires_in_seconds])
    device_code = SecureRandom.hex(32)

    context[:device_request] = { device_code: device_code }
    context[:grant] = UserApiKey::DeviceAuth::Grant.build(
      request_params,
      client,
      scopes,
      expires_in_seconds,
      device_code,
    )
    UserApiKey::DeviceAuth::PayloadBuilder.validate_size!(context[:grant])
  end

  def validate_grant_size(grant:)
    UserApiKey::DeviceAuth::KeyCreator.validate_grant_size!(grant)
  end

  def reserve_codes(device_request:, grant:)
    codes = UserApiKey::DeviceAuth::CodeRegistry.reserve_for(device_request[:device_code])

    grant.assign_codes!(user_code: codes.user_code, request_token: codes.request_token)
    device_request[:user_code] = codes.user_code
    device_request[:request_token] = codes.request_token
  end

  def store_grant(device_request:, grant:, options:)
    UserApiKey::DeviceAuth::KeyCreator.validate_grant_size!(grant)
    UserApiKey::DeviceAuth::GrantStore.save!(grant, ttl: UserApiKey::DeviceAuth::DEVICE_AUTH_TTL)
    UserApiKey::DeviceAuth.trace(
      "device_auth.create.succeeded",
      request_id: options.request_id,
      client_id: grant.client_id,
      device_code: grant.device_code,
      request_token: grant.request_token,
      user_code: grant.user_code,
    )
  end
end
