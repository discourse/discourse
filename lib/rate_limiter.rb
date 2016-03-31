require_dependency 'rate_limiter/limit_exceeded'
require_dependency 'rate_limiter/on_create_record'

# A redis backed rate limiter.
class RateLimiter

  attr_reader :max, :secs, :user, :key

  def self.key_prefix
    "l-rate-limit:"
  end

  def self.disable
    @disabled = true
  end

  def self.enable
    @disabled = false
  end

  # We don't observe rate limits in test mode
  def self.disabled?
    @disabled || Rails.env.test?
  end

  def self.clear_all!
    $redis.delete_prefixed(RateLimiter.key_prefix)
  end

  def build_key(type)
    "#{RateLimiter.key_prefix}:#{@user && @user.id}:#{type}"
  end

  def initialize(user, type, max, secs)
    @user = user
    @type = type
    @key = build_key(type)
    @max = max
    @secs = secs
  end

  def clear!
    $redis.del(@key)
  end

  def can_perform?
    rate_unlimited? || is_under_limit?
  end

  def performed!
    return if rate_unlimited?

    if is_under_limit?
      # simple ring buffer.
      $redis.lpush(@key, Time.now.to_i)
      $redis.ltrim(@key, 0, @max - 1)

      # let's ensure we expire this key at some point, otherwise we have leaks
      $redis.expire(@key, @secs * 2)
    else
      raise RateLimiter::LimitExceeded.new(seconds_to_wait, @type)
    end
  end

  def rollback!
    return if RateLimiter.disabled?
    $redis.lpop(@key)
  end

  def remaining
    return @max if @user && @user.staff?

    arr = $redis.lrange(@key, 0, @max) || []
    t0 = Time.now.to_i
    arr.reject! {|a| (t0 - a.to_i) > @secs}
    @max - arr.size
  end

  private

  def seconds_to_wait
    @secs - age_of_oldest
  end

  def age_of_oldest
    # age of oldest event in buffer, in seconds
    Time.now.to_i - $redis.lrange(@key, -1, -1).first.to_i
  end

  def is_under_limit?
    # number of events in buffer less than max allowed? OR
    ($redis.llen(@key) < @max) ||
    # age bigger than silding window size?
    (age_of_oldest > @secs)
  end

  def rate_unlimited?
    !!(RateLimiter.disabled? || (@user && @user.staff?))
  end
end
