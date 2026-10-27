# frozen_string_literal: true

module DiscourseWorkflows
  # Remembers what a composer paused trigger already fired for, so each phrase fires once per
  # draft and triggers without phrases don't fire on every pause.
  module ComposerPausedClaims
    PHRASES_TTL = 1.day
    NO_PHRASES_INTERVAL = 15.seconds
    RATE_LIMIT = 20
    RATE_PERIOD = 1.minute

    # Returns the phrases that haven't fired yet in this scope ([] for a trigger without
    # phrases), or nil when there is nothing new to fire.
    def self.claim(scope, published_trigger, phrases)
      key =
        "discourse_workflows:composer_paused:#{scope}:" \
          "#{published_trigger.workflow_id}:#{published_trigger.trigger_node_id}"

      if phrases.empty?
        [] if Discourse.redis.set(key, "1", ex: NO_PHRASES_INTERVAL.to_i, nx: true)
      else
        fresh = phrases.select { |phrase| Discourse.redis.sadd?(key, phrase) }
        Discourse.redis.expire(key, PHRASES_TTL.to_i)
        fresh.presence
      end
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
  end
end
