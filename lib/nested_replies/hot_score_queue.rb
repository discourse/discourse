# frozen_string_literal: true

module NestedReplies
  module HotScoreQueue
    QUEUE_KEY = "nested_replies:hot_score_queue"
    COOLDOWN_KEY = "nested_replies:hot_score_cooldowns"
    CLEANUP_CLAIM_KEY = "nested_replies:hot_score_cleanup_claim"
    CLEANUP_INTERVAL = 1.hour

    ENQUEUE_SCRIPT = DiscourseRedis::EvalHelper.new <<~LUA
      local topic_id = ARGV[1]
      local now = tonumber(ARGV[2])
      local capacity = tonumber(ARGV[3])
      local oldest_allowed = tonumber(ARGV[4])

      redis.call("ZREMRANGEBYSCORE", KEYS[1], "-inf", oldest_allowed)
      redis.call("ZREMRANGEBYSCORE", KEYS[2], "-inf", now)

      if redis.call("ZSCORE", KEYS[1], topic_id) then
        return 0
      end

      if redis.call("ZSCORE", KEYS[2], topic_id) then
        return -2
      end

      if redis.call("ZCARD", KEYS[1]) >= capacity then
        return -1
      end

      redis.call("ZADD", KEYS[1], now, topic_id)
      return 1
    LUA

    POP_SCRIPT = DiscourseRedis::EvalHelper.new <<~LUA
      redis.call("ZREMRANGEBYSCORE", KEYS[1], "-inf", ARGV[1])

      local members = redis.call("ZRANGE", KEYS[1], 0, 0)
      if #members == 0 then
        return nil
      end

      redis.call("ZREM", KEYS[1], members[1])
      return members[1]
    LUA

    def self.enqueue(topic_id, requested_at: Time.current)
      topic_id = topic_id.to_i
      return :invalid unless topic_id.positive?

      result =
        ENQUEUE_SCRIPT.eval(
          Discourse.redis,
          [redis_key(QUEUE_KEY), redis_key(COOLDOWN_KEY)],
          [
            topic_id,
            requested_at.to_f,
            SiteSetting.nested_replies_hot_max_pending_topics,
            requested_at.to_f - SiteSetting.nested_replies_hot_max_queue_age_minutes.minutes.to_i,
          ],
        )
      return :unavailable if result.nil?

      { -2 => :cooldown, -1 => :full, 0 => :duplicate, 1 => :queued }.fetch(
        result.to_i,
        :unavailable,
      )
    rescue Redis::BaseError
      :unavailable
    end

    def self.pop(now: Time.current)
      POP_SCRIPT.eval(
        Discourse.redis,
        [redis_key(QUEUE_KEY)],
        [now.to_f - SiteSetting.nested_replies_hot_max_queue_age_minutes.minutes.to_i],
      )&.to_i
    rescue Redis::BaseError
      nil
    end

    def self.cooldown(topic_id, duration:, now: Time.current)
      topic_id = topic_id.to_i
      return if !topic_id.positive? || duration.to_i <= 0

      Discourse.redis.zadd(COOLDOWN_KEY, now.to_f + duration.to_i, topic_id)
    rescue Redis::BaseError
      nil
    end

    def self.clear_cooldown(topic_id)
      Discourse.redis.zrem(COOLDOWN_KEY, topic_id.to_i)
    rescue Redis::BaseError
      nil
    end

    def self.size
      Discourse.redis.zcard(QUEUE_KEY).to_i
    rescue Redis::BaseError
      0
    end

    def self.oldest_age(now: Time.current)
      first_entry = Discourse.redis.zrange(QUEUE_KEY, 0, 0, with_scores: true).first
      return 0.0 if first_entry.blank?

      [now.to_f - first_entry.last.to_f, 0.0].max
    rescue Redis::BaseError
      0.0
    end

    def self.claim_cleanup
      !!Discourse.redis.set(CLEANUP_CLAIM_KEY, "1", nx: true, ex: CLEANUP_INTERVAL.to_i)
    rescue Redis::BaseError
      false
    end

    def self.clear
      Discourse.redis.del(QUEUE_KEY, COOLDOWN_KEY, CLEANUP_CLAIM_KEY)
    end

    def self.redis_key(key)
      Discourse.redis.namespace_key(key)
    end
    private_class_method :redis_key
  end
end
