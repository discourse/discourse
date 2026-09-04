# frozen_string_literal: true

module Voice
  # Fixed-window weighted rate limiter. Unlike core RateLimiter, one call can
  # consume several units of budget — a signal request is accounted by the
  # events it relays, not by being a single HTTP request — so burst-heavy but
  # bounded traffic (a full-room Trickle ICE burst) passes while sustained
  # abuse is cut off.
  class ControlPlaneLimiter
    class << self
      def perform!(key, limit:, period:, weight: 1)
        return if RateLimiter.disabled?

        redis = Discourse.redis.without_namespace
        redis_key = Discourse.redis.namespace_key("voice-budget:#{key}")

        count = redis.incrby(redis_key, weight)
        ttl = redis.ttl(redis_key)
        if ttl < 0
          redis.expire(redis_key, period)
          ttl = period
        end

        raise RateLimiter::LimitExceeded.new(ttl, key) if count > limit
      end
    end
  end
end
