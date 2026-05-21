# frozen_string_literal: true

class UserApiKey::DeviceAuth::Deny
  include Service::Base

  params do
    attribute :device_code, :string

    validates :device_code, presence: true
  end

  step :deny_grant

  private

  def deny_grant(params:)
    denied = false

    UserApiKey::DeviceAuth::GrantStore.with_lock!(params.device_code) do
      grant = UserApiKey::DeviceAuth::GrantStore.load(params.device_code)

      if grant&.pending?
        grant.deny!
        UserApiKey::DeviceAuth::GrantStore.save!(
          grant,
          ttl: UserApiKey::DeviceAuth::GrantStore.ttl_for_update(params.device_code),
        )
        UserApiKey::DeviceAuth::CodeRegistry.delete_indexes_for(grant)
        denied = true
      elsif grant&.denied?
        denied = true
      end
    end

    fail!("grant_not_found") if !denied
  end
end
