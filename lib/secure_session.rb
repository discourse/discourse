# frozen_string_literal: true

# session that is not stored in cookie, expires after 1.hour unconditionally
class SecureSession
  def initialize(prefix)
    @prefix = prefix
  end

  def self.expiry
    @expiry ||= 1.hour.to_i
  end

  def self.expiry=(val)
    @expiry = val
  end

  def set(key, val, expires: nil)
    expires ||= SecureSession.expiry
    Discourse.redis.setex(prefixed_key(key), expires.to_i, val.to_s)
    true
  end

  def ttl(key)
    Discourse.redis.ttl(prefixed_key(key))
  end

  def [](key)
    Discourse.redis.get(prefixed_key(key))
  end

  def []=(key, val)
    if val == nil
      Discourse.redis.del(prefixed_key(key))
    else
      Discourse.redis.setex(prefixed_key(key), SecureSession.expiry.to_i, val.to_s)
    end
    val
  end

  private

  def prefixed_key(key)
    "#{@prefix}#{key}"
  end
end
