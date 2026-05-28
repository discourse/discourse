# frozen_string_literal: true

class UserApiKey::DeviceAuth::GrantStore
  REDIS_PREFIXES = [UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_REDIS_PREFIX].freeze
  CONSUME_LOCKED = :locked
  UNLOCK_SCRIPT = DiscourseRedis::EvalHelper.new <<~LUA
      if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("del", KEYS[1])
      else
        return 0
      end
    LUA

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

    grant = UserApiKey::DeviceAuth::Grant.from_json(serialized)
    grant if grant&.device_code == device_code
  rescue JSON::ParserError, ArgumentError, TypeError
    nil
  end

  def self.save!(grant, ttl:)
    Discourse.redis.setex(grant_key(grant.device_code), ttl.to_i, grant.to_json)
  end

  def self.delete(device_code)
    Discourse.redis.del(grant_key(device_code))
  end

  def self.consume_authorized(device_code, request_id: nil)
    return if !UserApiKey::DeviceAuth::DEVICE_CODE_REGEX.match?(device_code.to_s)

    consumed_grant = nil

    with_lock!(
      device_code,
      operation: "device_auth.poll.consume_authorized",
      request_id: request_id,
    ) do
      grant = load(device_code)
      if grant&.authorized?
        delete(device_code)
        consumed_grant = grant
      end
    end

    consumed_grant
  rescue Discourse::InvalidAccess
    CONSUME_LOCKED
  end

  def self.ttl_for_update(device_code)
    ttl = Discourse.redis.ttl(grant_key(device_code)).to_i
    ttl.positive? ? ttl : UserApiKey::DeviceAuth::DEVICE_AUTH_TTL.to_i
  end

  def self.authorized_payload_ttl(device_code)
    [ttl_for_update(device_code), UserApiKey::DeviceAuth::DEVICE_AUTHORIZED_PAYLOAD_TTL.to_i].min
  end

  def self.with_lock!(device_code, operation: "device_auth.lock", request_id: nil)
    lock_key = self.lock_key(device_code)
    namespaced_lock_key = namespaced_key(lock_key)
    lock_token = SecureRandom.hex
    lock_acquired = false

    unless Discourse.redis.set(
             lock_key,
             lock_token,
             nx: true,
             ex: UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_TTL.to_i,
           )
      UserApiKey::DeviceAuth.trace(
        "#{operation}.failed",
        request_id: request_id,
        reason: "lock_busy",
        device_code: device_code,
      )
      raise Discourse::InvalidAccess
    end

    lock_acquired = true

    yield
  ensure
    release_lock(namespaced_lock_key, lock_token) if lock_acquired
  end

  def self.namespaced_key(key)
    if Discourse.redis.respond_to?(:namespace_key)
      Discourse.redis.namespace_key(key)
    else
      key
    end
  end

  def self.release_lock(namespaced_lock_key, lock_token)
    UNLOCK_SCRIPT.eval(Discourse.redis, [namespaced_lock_key], [lock_token])
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
