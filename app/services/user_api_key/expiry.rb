# frozen_string_literal: true

class UserApiKey::Expiry
  MAX_EXPIRES_IN_SECONDS_DIGITS = 10

  def self.parse_seconds!(value)
    return if value.blank?

    value = value.to_s
    if value.bytesize > MAX_EXPIRES_IN_SECONDS_DIGITS || !value.match?(/\A\d+\z/)
      raise Discourse::InvalidParameters.new(:expires_in_seconds)
    end

    seconds = Integer(value, 10)
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
