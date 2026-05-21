# frozen_string_literal: true

class UserApiKey::DeviceAuth::GrantStore
  REDIS_PREFIXES = [UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_REDIS_PREFIX].freeze

  def self.grant_key(device_code)
    "#{UserApiKey::DeviceAuth::DEVICE_CODE_REDIS_PREFIX}#{device_code}"
  end

  def self.lock_key(device_code)
    "#{UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_REDIS_PREFIX}#{device_code}"
  end

  def self.load(device_code)
    return if !UserApiKey::DeviceAuth::DEVICE_CODE_REGEX.match?(device_code.to_s)

    serialized = Discourse.redis.get(grant_key(device_code))
    return if serialized.blank?

    grant = JSON.parse(serialized)
    grant if grant["device_code"] == device_code
  rescue JSON::ParserError
    nil
  end

  def self.save!(grant, ttl:)
    Discourse.redis.setex(grant_key(grant["device_code"]), ttl.to_i, grant.to_json)
  end

  def self.delete(device_code)
    Discourse.redis.del(grant_key(device_code))
  end

  def self.ttl_for_update(device_code)
    ttl = Discourse.redis.ttl(grant_key(device_code)).to_i
    ttl.positive? ? ttl : UserApiKey::DeviceAuth::DEVICE_AUTH_TTL.to_i
  end

  def self.authorized_payload_ttl(device_code)
    [ttl_for_update(device_code), UserApiKey::DeviceAuth::DEVICE_AUTHORIZED_PAYLOAD_TTL.to_i].min
  end

  def self.with_lock!(device_code)
    lock_key = self.lock_key(device_code)
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
    Discourse
      .redis
      .scan_each(match: "#{UserApiKey::DeviceAuth::DEVICE_CODE_REDIS_PREFIX}*") do |key|
        device_code = key.delete_prefix(UserApiKey::DeviceAuth::DEVICE_CODE_REDIS_PREFIX)
        Discourse.redis.del(key) if UserApiKey::DeviceAuth::DEVICE_CODE_REGEX.match?(device_code)
      end

    REDIS_PREFIXES.each do |prefix|
      Discourse.redis.scan_each(match: "#{prefix}*") { |key| Discourse.redis.del(key) }
    end
  end
end
