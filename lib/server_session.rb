# frozen_string_literal: true

require "active_support/message_pack"

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
    payload = ActiveSupport::MessagePack.dump(val)
    Discourse.redis.setex(prefixed_key(key), expires.to_i, payload)
    true
  end
  alias_method :[]=, :set

  def [](key)
    deserialize(Discourse.redis.get(prefixed_key(key)))
  end

  def getdel(key)
    deserialize(Discourse.redis.getdel(prefixed_key(key)))
  end

  def delete(key)
    Discourse.redis.del(prefixed_key(key))
  end

  def ttl(key)
    Discourse.redis.ttl(prefixed_key(key))
  end

  private

  def deserialize(raw)
    ActiveSupport::MessagePack.load(raw)
  rescue StandardError
    raw
  end

  def prefixed_key(key)
    "#{@prefix}#{key}"
  end
end
