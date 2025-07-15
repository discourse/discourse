# frozen_string_literal: true

# session that is not stored in cookie, expires after 1.hour unconditionally
class SecureSession
  def initialize(prefix)
    @prefix = prefix
  end

  def self.expiry
    Rails.logger.warn("!~!~!~! in self.expiry, before: #{@expiry}")
    @expiry ||= 1.hour.to_i
    Rails.logger.warn("!~!~!~! in self.expiry, after: #{@expiry}")
    @expiry
  end

  def self.expiry=(val)
    Rails.logger.warn("!~!~!~! in self.expiry=")
    @expiry = val
  end

  def set(key, val, expires: nil)
    Rails.logger.warn("!~!~!~! in SecureSession.set #{key}, #{val}, #{expires}")
    expires ||= SecureSession.expiry
    Rails.logger.warn("!~!~!~! in SecureSession.set expires: #{expires}")
    Discourse.redis.setex(prefixed_key(key), expires.to_i, val.to_s)
    true
  end

  def ttl(key)
    Rails.logger.warn("!~!~!~! SecureSession.ttl, expiry: #{@expiry}")
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
  end

  private

  def prefixed_key(key)
    "#{@prefix}#{key}"
  end
end
