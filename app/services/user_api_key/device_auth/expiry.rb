# frozen_string_literal: true

class UserApiKey::DeviceAuth::Expiry
  def self.parse_seconds!(value)
    return if value.blank?

    seconds = Integer(value.to_s, 10)
    max_seconds = SiteSetting.max_user_api_key_expiry_days.to_i.days.to_i

    if seconds <= 0 || max_seconds <= 0 || seconds > max_seconds
      raise Discourse::InvalidParameters.new(:expires_in_seconds)
    end

    seconds
  rescue ArgumentError, TypeError
    raise Discourse::InvalidParameters.new(:expires_in_seconds)
  end

  def self.requested_expires_at(expires_in_seconds)
    expires_in_seconds.present? ? Time.zone.now + expires_in_seconds.to_i.seconds : nil
  end
end
