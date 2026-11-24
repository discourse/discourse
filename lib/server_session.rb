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

  COMPARE_AND_SET = DiscourseRedis::EvalHelper.new <<~LUA
    if redis.call('GET', KEYS[1]) ~= ARGV[1] then return 0 end
    if ARGV[2] then
      redis.call('SET', KEYS[1], ARGV[2], 'KEEPTTL')
    else
      redis.call('DEL', KEYS[1])
    end
    return 1
  LUA
  private_constant :COMPARE_AND_SET

  def initialize(prefix)
    @prefix = prefix
  end

  def set(key, val, expires: expiry)
    Discourse.redis.setex(prefixed_key(key), expires.to_i, ActiveSupport::MessagePack.dump(val))
    true
  end
  alias_method :[]=, :set

  def [](key)
    raw = Discourse.redis.get(prefixed_key(key))
    begin
      ActiveSupport::MessagePack.load(raw)
    rescue StandardError
      raw
    end
  end

  # Replace a previously read value without extending its lifetime. A nil replacement deletes it.
  # `expected` must contain only primitive types that round-trip byte-identically via MessagePack.
  def compare_and_set(key, expected:, replacement:)
    redis = Discourse.redis
    args = [ActiveSupport::MessagePack.dump(expected)]
    args << ActiveSupport::MessagePack.dump(replacement) unless replacement.nil?
    DiscourseRedis.ignore_readonly do
      COMPARE_AND_SET.eval(redis, [redis.namespace_key(prefixed_key(key))], args) == 1
    end
  end

  def delete(key)
    Discourse.redis.del(prefixed_key(key))
  end

  def ttl(key)
    Discourse.redis.ttl(prefixed_key(key))
  end

  private

  def prefixed_key(key)
    "#{@prefix}#{key}"
  end
end
