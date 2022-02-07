# frozen_string_literal: true

# A redis backed rate limiter.
class RateLimiter

  attr_reader :max, :secs, :user, :key, :error_code

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

  def initialize(user, type, max, secs, global: false, aggressive: false, error_code: nil, apply_limit_to_staff: false, staff_limit: { max: nil, secs: nil })
    @user = user
    @type = type
    @key = build_key(type)
    @max = max
    @secs = secs
    @global = global
    @aggressive = aggressive
    @error_code = error_code
    @apply_limit_to_staff = apply_limit_to_staff
    @staff_limit = staff_limit

    # override the default values if staff user, and staff specific max is passed
    if @user&.staff? && !@apply_limit_to_staff && @staff_limit[:max].present?
      @max = @staff_limit[:max]
      @secs = @staff_limit[:secs]
    end
  end

  def clear!
    redis.del(prefixed_key)
  end

  def can_perform?
    rate_unlimited? || is_under_limit?
  end

  def seconds_to_wait(now = Time.now.to_i)
    @secs - age_of_oldest(now)
  end

  # reloader friendly
  unless defined? PERFORM_LUA
    PERFORM_LUA = <<~LUA
      local now = tonumber(ARGV[1])
      local secs = tonumber(ARGV[2])
      local max = tonumber(ARGV[3])

      local key = KEYS[1]


      if ((tonumber(redis.call("LLEN", key)) < max) or
          (now - tonumber(redis.call("LRANGE", key, -1, -1)[1])) >= secs) then
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

  unless defined? PERFORM_LUA_AGGRESSIVE
    PERFORM_LUA_AGGRESSIVE = <<~LUA
      local now = tonumber(ARGV[1])
      local secs = tonumber(ARGV[2])
      local max = tonumber(ARGV[3])

      local key = KEYS[1]

      local return_val = 0

      if ((tonumber(redis.call("LLEN", key)) < max) or
          (now - tonumber(redis.call("LRANGE", key, -1, -1)[1])) >= secs) then
        return_val = 1
      else
        return_val = 0
      end

      redis.call("LPUSH", key, now)
      redis.call("LTRIM", key, 0, max - 1)
      redis.call("EXPIRE", key, secs * 2)

      return return_val
    LUA

    PERFORM_LUA_AGGRESSIVE_SHA = Digest::SHA1.hexdigest(PERFORM_LUA_AGGRESSIVE)
  end

  def performed!(raise_error: true)
    return true if rate_unlimited?
    now = Time.now.to_i
    if ((@max || 0) <= 0) || rate_limiter_allowed?(now)
      raise RateLimiter::LimitExceeded.new(seconds_to_wait(now), @type, @error_code) if raise_error
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
  rescue Redis::CommandError => e
    if e.message =~ /READONLY/
      # TODO,switch to in-memory rate limiter
    else
      raise
    end
  end

  def remaining
    return @max if @user && @user.staff?

    arr = redis.lrange(prefixed_key, 0, @max) || []
    t0 = Time.now.to_i
    arr.reject! { |a| (t0 - a.to_i) > @secs }
    @max - arr.size
  end

  private

  def rate_limiter_allowed?(now)
    lua, lua_sha = nil
    if @aggressive
      lua = PERFORM_LUA_AGGRESSIVE
      lua_sha = PERFORM_LUA_AGGRESSIVE_SHA
    else
      lua = PERFORM_LUA
      lua_sha = PERFORM_LUA_SHA
    end

    eval_lua(lua, lua_sha, [prefixed_key], [now, @secs, @max]) == 0
  end

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

  def age_of_oldest(now)
    # age of oldest event in buffer, in seconds
    now - redis.lrange(prefixed_key, -1, -1).first.to_i
  end

  def is_under_limit?
    now = Time.now.to_i

    # number of events in buffer less than max allowed? OR
    (redis.llen(prefixed_key) < @max) ||
    # age bigger than sliding window size?
    (age_of_oldest(now) >= @secs)
  end

  def rate_unlimited?
    !!(RateLimiter.disabled? || (@user&.staff? && !@apply_limit_to_staff && @staff_limit[:max].nil?))
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
