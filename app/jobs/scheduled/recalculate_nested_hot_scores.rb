# frozen_string_literal: true

module Jobs
  class RecalculateNestedHotScores < ::Jobs::Scheduled
    every 1.minute

    cluster_concurrency 1

    MIN_STATEMENT_TIME_MS = 100

    def execute(_args = {})
      return unless SiteSetting.nested_replies_enabled
      return unless SiteSetting.nested_replies_hot_sort_enabled

      started_at = monotonic_time
      topics_inspected = 0
      topics_rebuilt = 0
      posts_rebuilt = 0
      failures = 0

      while topics_inspected < SiteSetting.nested_replies_hot_max_topics_per_run
        timeout_ms = remaining_database_time_ms(started_at)
        break if timeout_ms < MIN_STATEMENT_TIME_MS

        topic_id = NestedReplies::HotScoreQueue.pop
        break if topic_id.blank?

        topics_inspected += 1
        topic = Topic.includes(:nested_topic).find_by(id: topic_id)
        next unless eligible?(topic)
        next if NestedReplies::HotScoreCache.fresh?(topic)

        begin
          rebuilt_posts =
            NestedReplies::HotScoreCalculator.recalculate_topic(topic.id, timeout_ms: timeout_ms)
          NestedReplies::HotScoreQueue.clear_cooldown(topic.id)
          topics_rebuilt += 1
          posts_rebuilt += rebuilt_posts
        rescue ActiveRecord::QueryCanceled, PG::QueryCanceled => error
          failures += 1
          cooldown(topic.id)
          Discourse.warn_exception(
            error,
            message: "Timed out refreshing nested hot scores for topic #{topic.id}",
          )
          break
        rescue => error
          failures += 1
          cooldown(topic.id)
          Discourse.warn_exception(
            error,
            message: "Failed to refresh nested hot scores for topic #{topic.id}",
          )
        end
      end

      purge_result = purge_expired_cache(started_at)
      return if topics_inspected.zero? && purge_result.blank?

      DiscourseEvent.trigger(
        :nested_replies_hot_scores_processed,
        {
          topics_inspected: topics_inspected,
          topics_rebuilt: topics_rebuilt,
          posts_rebuilt: posts_rebuilt,
          failures: failures,
          cooldowns_started: failures,
          queue_depth: NestedReplies::HotScoreQueue.size,
          oldest_queued_age: NestedReplies::HotScoreQueue.oldest_age,
          scores_purged: purge_result&.fetch(:scores_removed, 0).to_i,
          snapshots_purged: purge_result&.fetch(:snapshots_removed, 0).to_i,
          duration_seconds: monotonic_time - started_at,
        },
        continue_on_error: true,
      )
    end

    private

    def eligible?(topic)
      topic.present? && topic.deleted_at.nil? && topic.regular? && topic.nested_view? &&
        topic.posts_count.to_i > NestedReplies::HotScoreCache.small_topic_post_limit &&
        NestedReplies::HotScoreCache.active_topic?(topic)
    end

    def cooldown(topic_id)
      NestedReplies::HotScoreQueue.cooldown(
        topic_id,
        duration: SiteSetting.nested_replies_hot_failure_cooldown_minutes.minutes,
      )
    end

    def purge_expired_cache(started_at)
      return unless NestedReplies::HotScoreQueue.claim_cleanup

      remaining_ms = remaining_database_time_ms(started_at)
      return if remaining_ms < MIN_STATEMENT_TIME_MS * 2

      NestedReplies::HotScoreCache.purge_expired(
        timeout_ms: [remaining_ms / 2, MIN_STATEMENT_TIME_MS].max,
      )
    rescue ActiveRecord::QueryCanceled, PG::QueryCanceled => error
      Discourse.warn_exception(error, message: "Timed out purging nested hot score cache")
      nil
    rescue => error
      Discourse.warn_exception(error, message: "Failed to purge nested hot score cache")
      nil
    end

    def remaining_database_time_ms(started_at)
      elapsed_ms = (monotonic_time - started_at) * 1_000
      max_job_runtime_ms = SiteSetting.nested_replies_hot_max_job_runtime_ms
      (max_job_runtime_ms - elapsed_ms).floor.clamp(0, max_job_runtime_ms)
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
