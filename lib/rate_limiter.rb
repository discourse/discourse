# frozen_string_literal: true

# A redis backed rate limiter.
class RateLimiter

  attr_reader :max, :secs, :user, :key

  def self.key_prefix
    "l-rate-limit3:"
  end

  def self.disable
    @disabled = true
  end

  def self.enable
    @disabled = false
  end

  # We don't observe rate limits in test mode
  def self.disabled?
    @disabled
  end

  # Only used in test, only clears current namespace, does not clear globals
  def self.clear_all!
    Discourse.redis.delete_prefixed(RateLimiter.key_prefix)
  end

  def self.clear_all_global!
    Discourse.redis.without_namespace.keys("GLOBAL::#{key_prefix}*").each do |k|
      Discourse.redis.without_namespace.del k
    end
  end

  def build_key(type)
    "#{RateLimiter.key_prefix}:#{@user && @user.id}:#{type}"
  end

  def initialize(user, type, max, secs, global: false)
    @user = user
    @type = type
    @key = build_key(type)
    @max = max
    @secs = secs
    @global = global
  end

  def clear!
    redis.del(prefixed_key)
  end

  def can_perform?
    rate_unlimited? || is_under_limit?
  end

  # reloader friendly
  unless defined? PERFORM_LUA
    PERFORM_LUA = <<~LUA
      local now = tonumber(ARGV[1])
      local secs = tonumber(ARGV[2])
      local max = tonumber(ARGV[3])

      local key = KEYS[1]


      if ((tonumber(redis.call("LLEN", key)) < max) or
          (now - tonumber(redis.call("LRANGE", key, -1, -1)[1])) > secs) then
        redis.call("LPUSH", key, now)
        redis.call("LTRIM", key, 0, max - 1)
        redis.call("EXPIRE", key, secs * 2)

        return 1
      else
        return 0
      end
    LUA

    PERFORM_LUA_SHA = Digest::SHA1.hexdigest(PERFORM_LUA)
  end

  def performed!(raise_error: true)
    return true if rate_unlimited?
    now = Time.now.to_i

    if ((max || 0) <= 0) ||
       (eval_lua(PERFORM_LUA, PERFORM_LUA_SHA, [prefixed_key], [now, @secs, @max]) == 0)

      raise RateLimiter::LimitExceeded.new(seconds_to_wait, @type) if raise_error
      false
    else
      true
    end
  rescue Redis::CommandError => e
    if e.message =~ /READONLY/
      # TODO,switch to in-memory rate limiter
    else
      raise
    end
  end

  def rollback!
    return if RateLimiter.disabled?
    redis.lpop(prefixed_key)
  end

  def remaining
    return @max if @user && @user.staff?

    arr = redis.lrange(prefixed_key, 0, @max) || []
    t0 = Time.now.to_i
    arr.reject! { |a| (t0 - a.to_i) > @secs }
    @max - arr.size
  end

  private

  def prefixed_key
    if @global
      "GLOBAL::#{key}"
    else
      Discourse.redis.namespace_key(key)
    end
  end

  def redis
    Discourse.redis.without_namespace
  end

  def seconds_to_wait
    @secs - age_of_oldest
  end

  def age_of_oldest
    # age of oldest event in buffer, in seconds
    Time.now.to_i - redis.lrange(prefixed_key, -1, -1).first.to_i
  end

  def is_under_limit?
    # number of events in buffer less than max allowed? OR
    (redis.llen(prefixed_key) < @max) ||
    # age bigger than silding window size?
    (age_of_oldest > @secs)
  end

  def rate_unlimited?
    !!(RateLimiter.disabled? || (@user && @user.staff?))
  end

  def eval_lua(lua, sha, keys, args)
    redis.evalsha(sha, keys, args)
  rescue Redis::CommandError => e
    if e.to_s =~ /^NOSCRIPT/
      redis.eval(lua, keys, args)
    else
      raise
    end
  end
end
