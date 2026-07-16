# frozen_string_literal: true

module NestedReplies
  module HotScoreCache
    Decision = Struct.new(:effective_sort, :mode, :enqueue_result, keyword_init: true)

    PURGE_SCORE_BATCH_SIZE = 10_000
    PURGE_SNAPSHOT_BATCH_SIZE = 100
    MAX_PURGE_STATEMENT_TIMEOUT_MS = 1_000

    def self.small_topic_post_limit
      SiteSetting.nested_replies_hot_small_topic_post_limit
    end

    def self.snapshot_ttl
      SiteSetting.nested_replies_hot_snapshot_ttl_minutes.minutes
    end

    def self.max_stale_age
      SiteSetting.nested_replies_hot_max_stale_age_days.days
    end

    def self.resolve(topic, requested_sort, requester: nil)
      return Decision.new(effective_sort: requested_sort, mode: :not_hot) if requested_sort != "hot"

      if !SiteSetting.nested_replies_enabled || !SiteSetting.nested_replies_hot_sort_enabled
        return record(Decision.new(effective_sort: "top", mode: :disabled))
      end

      if topic.deleted_at.present? || !topic.regular? || !topic.nested_view?
        return record(Decision.new(effective_sort: "top", mode: :ineligible))
      end

      if topic.posts_count.to_i <= small_topic_post_limit
        return record(Decision.new(effective_sort: "top", mode: :small_topic))
      end

      snapshot = snapshot(topic.id)
      return fallback_with_refresh(topic.id, requester, mode: :missing) if snapshot.blank?

      if snapshot.formula_version.to_i != HotScoreCalculator.formula_version
        return fallback_with_refresh(topic.id, requester, mode: :wrong_formula)
      end

      calculated_at = snapshot.calculated_at
      if calculated_at.blank? || calculated_at < max_stale_age.ago
        return fallback_with_refresh(topic.id, requester, mode: :expired)
      end

      if calculated_at < snapshot_ttl.ago
        enqueue_result = request_refresh(topic.id, requester)
        return(
          record(Decision.new(effective_sort: "hot", mode: :stale, enqueue_result: enqueue_result))
        )
      end

      record(Decision.new(effective_sort: "hot", mode: :fresh))
    end

    def self.effective_sort(topic, requested_sort, requester: nil)
      resolve(topic, requested_sort, requester: requester).effective_sort
    end

    def self.fresh?(topic)
      snapshot = snapshot(topic.id)
      snapshot.present? && snapshot.formula_version.to_i == HotScoreCalculator.formula_version &&
        snapshot.calculated_at.present? && snapshot.calculated_at >= snapshot_ttl.ago
    end

    def self.snapshot(topic_id)
      DB.query(<<~SQL, topic_id: topic_id).first
        SELECT formula_version,
               calculated_at
        FROM nested_hot_score_snapshots
        WHERE topic_id = :topic_id
      SQL
    end

    def self.purge_expired(cutoff: nil, timeout_ms: MAX_PURGE_STATEMENT_TIMEOUT_MS)
      cutoff ||= max_stale_age.ago
      timeout_ms = timeout_ms.to_i.clamp(1, MAX_PURGE_STATEMENT_TIMEOUT_MS)
      ActiveRecord::Base.transaction do
        DB.exec "SET LOCAL statement_timeout = #{timeout_ms}"
        DB.exec(
          "SET LOCAL lock_timeout = #{[timeout_ms, SiteSetting.nested_replies_hot_lock_timeout_ms].min}",
        )

        scores_removed = DB.exec(<<~SQL, cutoff: cutoff, batch_size: PURGE_SCORE_BATCH_SIZE)
            WITH scores_to_remove AS MATERIALIZED (
            SELECT scores.post_id
            FROM nested_hot_post_scores scores
            LEFT JOIN nested_hot_score_snapshots snapshots
              ON snapshots.topic_id = scores.topic_id
            WHERE snapshots.topic_id IS NULL
               OR snapshots.calculated_at < :cutoff
            ORDER BY snapshots.calculated_at NULLS FIRST, scores.post_id
              LIMIT :batch_size
            )
            DELETE FROM nested_hot_post_scores scores
            USING scores_to_remove
            WHERE scores.post_id = scores_to_remove.post_id
          SQL

        snapshots_removed = DB.exec(<<~SQL, cutoff: cutoff, batch_size: PURGE_SNAPSHOT_BATCH_SIZE)
            WITH snapshots_to_remove AS MATERIALIZED (
              SELECT snapshots.topic_id
              FROM nested_hot_score_snapshots snapshots
              WHERE snapshots.calculated_at < :cutoff
                AND NOT EXISTS (
                  SELECT 1
                  FROM nested_hot_post_scores scores
                  WHERE scores.topic_id = snapshots.topic_id
                )
              ORDER BY snapshots.calculated_at
              LIMIT :batch_size
            )
            DELETE FROM nested_hot_score_snapshots snapshots
            USING snapshots_to_remove
            WHERE snapshots.topic_id = snapshots_to_remove.topic_id
          SQL

        { scores_removed: scores_removed, snapshots_removed: snapshots_removed }
      end
    end

    def self.fallback_with_refresh(topic_id, requester, mode:)
      enqueue_result = request_refresh(topic_id, requester)
      record(Decision.new(effective_sort: "top", mode: mode, enqueue_result: enqueue_result))
    end
    private_class_method :fallback_with_refresh

    def self.request_refresh(topic_id, requester)
      allowed =
        RateLimiter.new(
          requester,
          "nested-hot-score-refresh",
          SiteSetting.nested_replies_hot_refresh_requests_per_minute,
          1.minute,
          apply_limit_to_staff: true,
        ).performed!(raise_error: false)
      return :requester_limited unless allowed

      HotScoreQueue.enqueue(topic_id)
    rescue Redis::BaseError
      :unavailable
    end
    private_class_method :request_refresh

    def self.record(decision)
      DiscourseEvent.trigger(
        :nested_replies_hot_sort_resolved,
        { mode: decision.mode, enqueue_result: decision.enqueue_result },
        continue_on_error: true,
      )
      decision
    end
    private_class_method :record
  end
end
