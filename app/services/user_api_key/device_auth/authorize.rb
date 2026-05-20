# frozen_string_literal: true

class UserApiKey::DeviceAuth::Authorize
  include Service::Base

  params do
    attribute :device_code, :string
    attribute :user_id, :integer

    validates :device_code, presence: true
    validates :user_id, presence: true
  end

  model :user

  try Discourse::InvalidParameters, Discourse::InvalidAccess do
    step :authorize_grant
  end

  private

  def fetch_user(params:)
    User.find_by(id: params.user_id)
  end

  def authorize_grant(params:, user:)
    UserApiKey::DeviceAuth::Store.with_grant_lock!(params.device_code) do
      grant = UserApiKey::DeviceAuth::Store.load_by_device_code(params.device_code)
      fail!("grant_not_found") if grant.blank? || grant["status"] != "pending"
      fail!("grant_not_found") if UserApiKey::DeviceAuth.grant_bound_to_another_user?(grant, user)

      grant["status"] = "authorized"
      grant["payload"] = UserApiKey::DeviceAuth.create_user_api_key_payload_from_grant!(grant, user)
      grant["authorized_at"] = Time.zone.now.iso8601

      UserApiKey::DeviceAuth::Store.save!(
        params.device_code,
        grant,
        ttl: UserApiKey::DeviceAuth::Store.authorized_payload_ttl(params.device_code),
      )
      UserApiKey::DeviceAuth::Store.delete_indexes(grant)
      context[:grant] = grant
    end
  end
end
