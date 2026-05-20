# frozen_string_literal: true

class UserApiKey::DeviceAuth::Store
  REDIS_PREFIXES = [
    UserApiKey::DeviceAuth::DEVICE_CODE_REDIS_PREFIX,
    UserApiKey::DeviceAuth::DEVICE_USER_CODE_REDIS_PREFIX,
    UserApiKey::DeviceAuth::DEVICE_REQUEST_REDIS_PREFIX,
    UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_REDIS_PREFIX,
  ].freeze

  def self.device_grant_key(device_code)
    "#{UserApiKey::DeviceAuth::DEVICE_CODE_REDIS_PREFIX}#{device_code}"
  end

  def self.device_user_code_key(user_code)
    "#{UserApiKey::DeviceAuth::DEVICE_USER_CODE_REDIS_PREFIX}#{user_code}"
  end

  def self.device_request_key(request_token)
    "#{UserApiKey::DeviceAuth::DEVICE_REQUEST_REDIS_PREFIX}#{request_token}"
  end

  def self.device_authorization_lock_key(device_code)
    "#{UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_REDIS_PREFIX}#{device_code}"
  end

  def self.load_by_user_code(user_code)
    device_code = Discourse.redis.get(device_user_code_key(user_code))
    return if device_code.blank?

    grant = load_by_device_code(device_code)
    Discourse.redis.del(device_user_code_key(user_code)) if grant.blank?
    grant
  end

  def self.load_by_request_token(request_token)
    return if !UserApiKey::DeviceAuth.valid_request_token?(request_token)

    device_code = Discourse.redis.get(device_request_key(request_token))
    return if device_code.blank?

    grant = load_by_device_code(device_code)
    Discourse.redis.del(device_request_key(request_token)) if grant.blank?
    grant
  end

  def self.load_by_device_code(device_code)
    return if !UserApiKey::DeviceAuth::DEVICE_CODE_REGEX.match?(device_code.to_s)

    serialized = Discourse.redis.get(device_grant_key(device_code))
    return if serialized.blank?

    grant = JSON.parse(serialized)
    grant if grant["device_code"] == device_code
  rescue JSON::ParserError
    nil
  end

  def self.save!(device_code, grant, ttl:)
    Discourse.redis.setex(device_grant_key(device_code), ttl.to_i, grant.to_json)
  end

  def self.delete_user_code(user_code)
    Discourse.redis.del(device_user_code_key(user_code))
  end

  def self.delete_grant(device_code)
    Discourse.redis.del(device_grant_key(device_code))
  end

  def self.delete_indexes(grant)
    delete_user_code(grant["user_code"]) if grant["user_code"].present?
    if grant["request_token"].present?
      Discourse.redis.del(device_request_key(grant["request_token"]))
    end
  end

  def self.reserve_user_code!(device_code)
    20.times do
      user_code = UserApiKey::DeviceAuth.generate_user_code
      if Discourse.redis.set(
           device_user_code_key(user_code),
           device_code,
           nx: true,
           ex: UserApiKey::DeviceAuth::DEVICE_AUTH_TTL.to_i,
         )
        return user_code
      end
    end

    raise Discourse::InvalidAccess
  end

  def self.reserve_request_token!(device_code)
    20.times do
      request_token = SecureRandom.urlsafe_base64(6)
      if Discourse.redis.set(
           device_request_key(request_token),
           device_code,
           nx: true,
           ex: UserApiKey::DeviceAuth::DEVICE_AUTH_TTL.to_i,
         )
        return request_token
      end
    end

    raise Discourse::InvalidAccess
  end

  def self.ttl_for_update(device_code)
    ttl = Discourse.redis.ttl(device_grant_key(device_code)).to_i
    ttl.positive? ? ttl : UserApiKey::DeviceAuth::DEVICE_AUTH_TTL.to_i
  end

  def self.authorized_payload_ttl(device_code)
    [ttl_for_update(device_code), UserApiKey::DeviceAuth::DEVICE_AUTHORIZED_PAYLOAD_TTL.to_i].min
  end

  def self.with_grant_lock!(device_code)
    lock_key = device_authorization_lock_key(device_code)
    lock_token = SecureRandom.hex

    unless Discourse.redis.set(
             lock_key,
             lock_token,
             nx: true,
             ex: UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_TTL.to_i,
           )
      raise Discourse::InvalidAccess
    end

    yield
  ensure
    Discourse.redis.del(lock_key) if lock_key && Discourse.redis.get(lock_key) == lock_token
  end

  def self.clear!
    REDIS_PREFIXES.each do |prefix|
      Discourse.redis.scan_each(match: "#{prefix}*") { |key| Discourse.redis.del(key) }
    end
  end
end
