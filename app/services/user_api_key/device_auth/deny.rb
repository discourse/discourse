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

    UserApiKey::DeviceAuth::Store.with_grant_lock!(params.device_code) do
      grant = UserApiKey::DeviceAuth::Store.load_by_device_code(params.device_code)

      if grant.present? && grant["status"] == "pending"
        grant["status"] = "denied"
        grant["denied_at"] = Time.zone.now.iso8601
        UserApiKey::DeviceAuth::Store.save!(
          params.device_code,
          grant,
          ttl: UserApiKey::DeviceAuth::Store.ttl_for_update(params.device_code),
        )
        UserApiKey::DeviceAuth::Store.delete_indexes(grant)
        denied = true
      elsif grant.present? && grant["status"] == "denied"
        denied = true
      end
    end

    fail!("grant_not_found") if !denied
  end
end
