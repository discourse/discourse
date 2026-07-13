# frozen_string_literal: true

module NestedReplies
  class RecalculationQueue
    HOT_POSTS_KEY = "nested-replies:pending-hot-posts"
    HOT_POSTS_IN_FLIGHT_KEY = "nested-replies:in-flight-hot-posts"
    HOT_TOPICS_KEY = "nested-replies:pending-hot-topics"
    STRUCTURAL_TOPICS_KEY = "nested-replies:pending-structural-topics"
    SCHEDULED_KEY = "nested-replies:recalculation-scheduled"
    SCHEDULE_TTL = 1.hour.to_i

    POP_SCRIPT = DiscourseRedis::EvalHelper.new(<<~LUA)
        local values = {}
        for index = 1, tonumber(ARGV[1]) do
          local value = redis.call("spop", KEYS[1])
          if not value then
            break
          end
          table.insert(values, value)
        end
        return values
      LUA

    # Topic rebuilds have invalid markers as a durable retry signal. Per-post
    # updates instead stay in flight until the worker explicitly acknowledges them.
    CLAIM_HOT_POSTS_SCRIPT = DiscourseRedis::EvalHelper.new(<<~LUA)
        local values = {}
        for index = 1, tonumber(ARGV[1]) do
          local value = redis.call("spop", KEYS[1])
          if not value then
            break
          end
          redis.call("sadd", KEYS[2], value)
          table.insert(values, value)
        end
        return values
      LUA

    RECOVER_HOT_POSTS_SCRIPT = DiscourseRedis::EvalHelper.new(<<~LUA)
        local values = redis.call("smembers", KEYS[1])
        for _, value in ipairs(values) do
          redis.call("sadd", KEYS[2], value)
        end
        redis.call("del", KEYS[1])
        return #values
      LUA

    FINISH_SCRIPT = DiscourseRedis::EvalHelper.new(<<~LUA)
        if redis.call("scard", KEYS[1]) > 0 or
           redis.call("scard", KEYS[2]) > 0 or
           redis.call("scard", KEYS[3]) > 0 or
           redis.call("scard", KEYS[4]) > 0 then
          return 1
        end
        redis.call("del", KEYS[5])
        return 0
      LUA

    def self.enqueue_hot_post_if_nested(post_id)
      DB.after_commit { enqueue_hot_post_if_nested_after_commit(post_id) }
    end

    def self.enqueue_hot_post(post_id)
      return if post_id.blank? || !SiteSetting.nested_replies_enabled

      queued = add_members(HOT_POSTS_KEY, [post_id])
      unless queued
        invalidate_hot_marker_for_post(post_id)
        return
      end
      schedule
    rescue => error
      begin
        invalidate_hot_marker_for_post(post_id)
      rescue => invalidation_error
        report_error(
          invalidation_error,
          "Failed to invalidate nested hot-score marker for post #{post_id}",
        )
      end
      report_error(error, "Failed to queue nested hot-score update for post #{post_id}")
    end

    def self.enqueue_topic_rebuilds(topic_ids, structural:, hot:)
      return [] unless SiteSetting.nested_replies_enabled

      topic_ids = normalize_ids(topic_ids)
      return [] if topic_ids.empty?

      structural_result = structural ? add_members(STRUCTURAL_TOPICS_KEY, topic_ids) : 0
      hot_result = hot ? add_members(HOT_TOPICS_KEY, topic_ids) : 0
      redis_unavailable = structural_result.nil? || hot_result.nil?
      structural_added = structural_result.to_i.positive?
      hot_added = hot_result.to_i.positive?

      if redis_unavailable
        invalidate_completion_markers(topic_ids, structural: structural, hot: hot)
      end
      return topic_ids unless structural_added || hot_added

      unless redis_unavailable
        invalidate_completion_markers(topic_ids, structural: structural_added, hot: hot_added)
      end
      schedule
      topic_ids
    rescue => error
      begin
        invalidate_completion_markers(topic_ids, structural: structural, hot: hot)
      rescue => invalidation_error
        report_error(
          invalidation_error,
          "Failed to invalidate nested reply markers for topics #{topic_ids.inspect}",
        )
      end
      report_error(error, "Failed to queue nested reply rebuilds for topics #{topic_ids.inspect}")
      []
    end

    def self.invalidate_completion_markers(topic_ids, structural:, hot:)
      topic_ids = normalize_ids(topic_ids)
      return if topic_ids.empty? || (!structural && !hot)

      assignments = []
      assignments << "structural_backfilled_at = NULL" if structural
      assignments << "hot_score_updated_at = NULL" if hot
      assignments << "updated_at = NOW()"

      DB.exec(<<~SQL, topic_ids: topic_ids)
          UPDATE nested_view_post_stats stats
          SET #{assignments.join(", ")}
          FROM posts
          WHERE posts.id = stats.post_id
            AND posts.topic_id IN (:topic_ids)
            AND posts.post_number = 1
        SQL
    end

    def self.eligible_topic_ids(topic_ids)
      topic_ids = normalize_ids(topic_ids)
      return [] if topic_ids.empty? || !SiteSetting.nested_replies_enabled

      DB.query_single(
        <<~SQL,
          SELECT topics.id
          FROM topics
          LEFT JOIN nested_topics ON nested_topics.topic_id = topics.id
          WHERE topics.id IN (:topic_ids)
            AND topics.deleted_at IS NULL
            AND topics.archetype = :archetype
            AND (:nested_by_default OR nested_topics.topic_id IS NOT NULL)
        SQL
        topic_ids: topic_ids,
        archetype: Archetype.default,
        nested_by_default: SiteSetting.nested_replies_default,
      )
    end

    def self.pop_batch(batch_size)
      {
        hot_post_ids: claim_hot_posts(batch_size),
        hot_topic_ids: pop(HOT_TOPICS_KEY, batch_size),
        structural_topic_ids: pop(STRUCTURAL_TOPICS_KEY, batch_size),
      }
    end

    def self.recover_hot_posts
      RECOVER_HOT_POSTS_SCRIPT.eval(
        Discourse.redis,
        [namespaced_key(HOT_POSTS_IN_FLIGHT_KEY), namespaced_key(HOT_POSTS_KEY)],
        [],
      ).to_i
    end

    def self.acknowledge_hot_posts(post_ids)
      post_ids = normalize_ids(post_ids)
      return if post_ids.empty?

      Discourse.redis.srem(HOT_POSTS_IN_FLIGHT_KEY, *post_ids)
    end

    def self.finish
      FINISH_SCRIPT.eval(
        Discourse.redis,
        [
          namespaced_key(HOT_POSTS_KEY),
          namespaced_key(HOT_TOPICS_KEY),
          namespaced_key(STRUCTURAL_TOPICS_KEY),
          namespaced_key(HOT_POSTS_IN_FLIGHT_KEY),
          namespaced_key(SCHEDULED_KEY),
        ],
        [],
      ) == 1
    end

    def self.clear
      Discourse.redis.del(
        HOT_POSTS_KEY,
        HOT_POSTS_IN_FLIGHT_KEY,
        HOT_TOPICS_KEY,
        STRUCTURAL_TOPICS_KEY,
        SCHEDULED_KEY,
      )
    end

    def self.enqueue_continuation
      Jobs.enqueue(:process_nested_reply_updates)
    rescue => error
      report_error(error, "Failed to continue nested reply recalculation")
    end

    def self.add_members(key, ids)
      ids = ids.compact.map(&:to_s).uniq
      return 0 if ids.empty?

      Discourse.redis.sadd(key, *ids)&.to_i
    end
    private_class_method :add_members

    def self.normalize_ids(ids)
      Array(ids).compact.map(&:to_i).select(&:positive?).uniq
    end
    private_class_method :normalize_ids

    def self.invalidate_hot_marker_for_post(post_id)
      topic_id = Post.with_deleted.where(id: post_id).pick(:topic_id)
      invalidate_completion_markers([topic_id], structural: false, hot: true) if topic_id
    end
    private_class_method :invalidate_hot_marker_for_post

    def self.enqueue_hot_post_if_nested_after_commit(post_id)
      return unless SiteSetting.nested_replies_enabled

      post = Post.with_deleted.find_by(id: post_id)
      return if post.blank? || post.post_number == 1
      return if HotScoreCalculator.public_post_types.exclude?(post.post_type)
      return if eligible_topic_ids([post.topic_id]).empty?

      enqueue_hot_post(post.id)
    rescue => error
      report_error(error, "Failed to queue nested hot-score update for post #{post_id}")
    end
    private_class_method :enqueue_hot_post_if_nested_after_commit

    def self.pop(key, batch_size)
      POP_SCRIPT.eval(Discourse.redis, [namespaced_key(key)], [batch_size]).map(&:to_i)
    end
    private_class_method :pop

    def self.claim_hot_posts(batch_size)
      CLAIM_HOT_POSTS_SCRIPT.eval(
        Discourse.redis,
        [namespaced_key(HOT_POSTS_KEY), namespaced_key(HOT_POSTS_IN_FLIGHT_KEY)],
        [batch_size],
      ).map(&:to_i)
    end
    private_class_method :claim_hot_posts

    def self.namespaced_key(key)
      Discourse.redis.namespace_key(key)
    end
    private_class_method :namespaced_key

    def self.schedule
      scheduled = Discourse.redis.set(SCHEDULED_KEY, "1", nx: true, ex: SCHEDULE_TTL)
      return unless scheduled

      Jobs.enqueue(:process_nested_reply_updates)
    rescue => error
      Discourse.redis.del(SCHEDULED_KEY) if scheduled
      report_error(error, "Failed to schedule nested reply recalculation")
    end
    private_class_method :schedule

    def self.report_error(error, message)
      Discourse.warn_exception(error, message: message)
    end
    private_class_method :report_error
  end
end
