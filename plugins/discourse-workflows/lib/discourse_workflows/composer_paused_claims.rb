# frozen_string_literal: true

module DiscourseWorkflows
  # Remembers what a composer paused trigger already fired for, so each phrase fires once per
  # draft and triggers without phrases don't fire on every pause.
  module ComposerPausedClaims
    PHRASES_TTL = 1.day
    NO_PHRASES_INTERVAL = 15.seconds
    RATE_LIMIT = 20
    RATE_PERIOD = 1.minute
    ATTEMPT_LIMIT = 60

    # Returns the phrases that haven't fired yet in this scope ([] for a trigger without
    # phrases), or nil when there is nothing new to fire.
    def self.claim(scope, published_trigger, phrases)
      key = key(scope, published_trigger)

      if phrases.empty?
        [] if Discourse.redis.set(key, "1", ex: NO_PHRASES_INTERVAL.to_i, nx: true)
      else
        fresh = phrases.select { |phrase| Discourse.redis.sadd?(key, phrase) }
        Discourse.redis.expire(key, PHRASES_TTL.to_i)
        fresh.presence
      end
    end

    # Gives back a claim whose workflow didn't fire, so it can fire later.
    def self.release(scope, published_trigger, phrases)
      key = key(scope, published_trigger)
      phrases.empty? ? Discourse.redis.del(key) : Discourse.redis.srem(key, phrases)
    end

    # Lets callers skip matching the phrases that already fired.
    def self.unclaimed(scope, published_trigger, phrases)
      phrases - Discourse.redis.smembers(key(scope, published_trigger))
    end

    def self.rate_limiter(user)
      RateLimiter.new(
        user,
        "workflow_composer_paused",
        RATE_LIMIT,
        RATE_PERIOD.to_i,
        apply_limit_to_staff: true,
      )
    end

    # Every request costs a scan, while the run limit only counts workflows that fired.
    def self.attempt_rate_limiter(user)
      RateLimiter.new(
        user,
        "workflow_composer_paused_attempt",
        ATTEMPT_LIMIT,
        RATE_PERIOD.to_i,
        apply_limit_to_staff: true,
      )
    end

    def self.key(scope, published_trigger)
      "discourse_workflows:composer_paused:#{scope}:" \
        "#{published_trigger.workflow_id}:#{published_trigger.trigger_node_id}"
    end

    private_class_method :key
  end
end
