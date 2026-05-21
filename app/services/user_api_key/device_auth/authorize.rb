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
    UserApiKey::DeviceAuth::GrantStore.with_lock!(params.device_code) do
      grant = UserApiKey::DeviceAuth::GrantStore.load(params.device_code)
      fail!("grant_not_found") if grant.blank? || !grant.pending?
      fail!("grant_not_found") if grant.bound_to_another_user?(user)

      key = UserApiKey::DeviceAuth::KeyCreator.create!(grant, user)
      grant.authorize!(
        payload: UserApiKey::DeviceAuth::PayloadBuilder.encrypted_payload!(grant, key),
      )

      UserApiKey::DeviceAuth::GrantStore.save!(
        grant,
        ttl: UserApiKey::DeviceAuth::GrantStore.authorized_payload_ttl(params.device_code),
      )
      UserApiKey::DeviceAuth::CodeRegistry.delete_indexes_for(grant)
      context[:grant] = grant
    end
  end
end
