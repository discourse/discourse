# frozen_string_literal: true

# Session that is not stored in cookie, expires after 1.hour unconditionally
class ServerSession
  delegate :expiry, to: :class

  class << self
    def expiry
      @expiry ||= 1.hour.to_i
    end

    def expiry=(val)
      @expiry = val
    end
  end

  def initialize(prefix)
    @prefix = prefix
  end

  def set(key, val, expires: expiry)
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
      Discourse.redis.setex(prefixed_key(key), expiry.to_i, val.to_s)
    end
  end

  private

  def prefixed_key(key)
    "#{@prefix}#{key}"
  end
end
