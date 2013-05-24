require_dependency 'rate_limiter/limit_exceeded'
require_dependency 'rate_limiter/on_create_record'

# A redis backed rate limiter.
class RateLimiter

  # We don't observe rate limits in test mode
  def self.disabled?
    Rails.env.test?
  end

  def initialize(user, key, max, secs)
    @user = user
    @key = "rate-limit:#{@user.id}:#{key}"
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

    result = $redis.incr(@key).to_i
    $redis.expire(@key, @secs) if result == 1
    if result > @max

      # In case we go over, clamp it to the maximum
      $redis.decr(@key)

      raise LimitExceeded.new($redis.ttl(@key))
    end
  end

  def rollback!
    return if RateLimiter.disabled?
    $redis.decr(@key)
  end

  private

  def is_under_limit?
    $redis.get(@key).to_i < @max
  end

  def rate_unlimited?
    !!(RateLimiter.disabled? || @user.staff?)
  end
end
