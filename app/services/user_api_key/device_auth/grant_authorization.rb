# frozen_string_literal: true

class UserApiKey::DeviceAuth::GrantAuthorization
  def self.bind_to_user!(grant, user)
    return false if bound_to_another_user?(grant, user)
    return true if authorized_for_user?(grant, user)

    grant["authorizing_user_id"] = user.id
    grant["authorizing_username"] = user.username
    grant["authorizing_at"] = Time.zone.now.iso8601
    UserApiKey::DeviceAuth::GrantStore.save!(
      grant,
      ttl: UserApiKey::DeviceAuth::GrantStore.ttl_for_update(grant["device_code"]),
    )
    true
  end

  def self.bound_to_another_user?(grant, user)
    grant["authorizing_user_id"].present? && grant["authorizing_user_id"] != user.id
  end

  def self.authorized_for_user?(grant, user)
    grant["authorizing_user_id"] == user.id
  end
end
