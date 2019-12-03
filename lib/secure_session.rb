# frozen_string_literal: true

# session that is not stored in cookie, expires after 1.hour unconditionally
class SecureSession
  def initialize(prefix)
    @prefix = prefix
  end

  def [](key)
    Discourse.redis.get("#{@prefix}#{key}")
  end

  def []=(key, val)
    if val == nil
      Discourse.redis.del("#{@prefix}#{key}")
    else
      Discourse.redis.setex("#{@prefix}#{key}", 1.hour, val.to_s)
    end
  end
end
