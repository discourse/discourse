# frozen_string_literal: true

class UserApiKey::OneTimePassword
  def self.issue(token:, credential:, user:)
    unless credential.is_a?(UserAuthToken) || credential.is_a?(UserApiKey) ||
             credential.is_a?(ApiKey)
      raise Discourse::InvalidAccess
    end

    Discourse.redis.setex(
      redis_key(token),
      10.minutes,
      JSON.generate(
        user_id: user.id,
        credential_type: credential.class.name,
        credential_id: credential.id,
      ),
    )
  end

  def self.user_for(token)
    value = Discourse.redis.get(redis_key(token))
    return if value.blank?

    payload = JSON.parse(value)
    return unless payload.is_a?(Hash)
    user_id = payload["user_id"]
    credential_id = payload["credential_id"]
    return unless user_id.is_a?(Integer) && credential_id.is_a?(Integer)

    credential =
      case payload["credential_type"]
      when "UserAuthToken"
        UserAuthToken.unexpired.find_by(id: credential_id)
      when "UserApiKey"
        UserApiKey.active.find_by(id: credential_id)
      when "ApiKey"
        ApiKey.active.find_by(id: credential_id)
      end
    return if credential.blank?

    if credential.is_a?(UserAuthToken)
      return if credential.user&.id != user_id
    elsif credential.is_a?(UserApiKey)
      return if credential.user_id != user_id
    elsif credential.user_id.present? && credential.user_id != user_id
      return
    end

    User.find_by(id: user_id)
  rescue JSON::ParserError, TypeError
    nil
  end

  def self.delete(token)
    Discourse.redis.del(redis_key(token))
  end

  def self.redis_key(token)
    "otp_#{token}"
  end
  private_class_method :redis_key
end
