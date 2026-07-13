# frozen_string_literal: true

module Jobs
  class RecalculateNestedHotScores < ::Jobs::Scheduled
    every 5.minutes

    cluster_concurrency 1

    # The next scheduled run resumes any remaining backlog.
    MAX_DRAIN_BATCHES = 20

    def execute(args = {})
      return unless SiteSetting.nested_replies_enabled

      args ||= {}
      if args[:topic_id].present?
        NestedReplies::HotScoreCalculator.recalculate_topic(args[:topic_id])
        return
      end

      topic_ids = stale_topic_ids(category_id: args[:category_id])
      failed = false
      topic_ids.each do |topic_id|
        NestedReplies::HotScoreCalculator.recalculate_topic(topic_id)
      rescue => error
        failed = true
        Discourse.warn_exception(
          error,
          message: "Failed to recalculate nested hot scores for topic #{topic_id}",
        )
      end

      unless failed
        enqueue_continuation(
          topic_ids,
          category_id: args[:category_id],
          drain_batch: [args[:drain_batch].to_i, 1].max,
        )
      end
    end

    private

    def stale_topic_ids(category_id: nil)
      category_id = category_id.to_i
      category_filter = category_id.positive? ? "AND topics.category_id = :category_id" : ""

      DB.query_single(
        <<~SQL,
          SELECT topics.id
          FROM topics
          JOIN posts original_post
            ON original_post.topic_id = topics.id
           AND original_post.post_number = 1
          LEFT JOIN nested_topics ON nested_topics.topic_id = topics.id
          LEFT JOIN nested_view_post_stats stats ON stats.post_id = original_post.id
          WHERE topics.deleted_at IS NULL
            AND topics.archetype = :archetype
            AND (:nested_by_default OR nested_topics.topic_id IS NOT NULL)
            #{category_filter}
            AND EXISTS (
              SELECT 1
              FROM posts replies
              WHERE replies.topic_id = topics.id
                AND replies.post_number > 1
                AND replies.post_type IN (
                  #{NestedReplies::HotScoreCalculator.public_post_types.join(", ")}
                )
            )
            AND (
              stats.hot_score_updated_at IS NULL
              OR (
                COALESCE(topics.last_posted_at, topics.created_at) >=
                  NOW() - :freshness_window * INTERVAL '1 second'
                AND stats.hot_score_updated_at <
                  NOW() - :refresh_interval * INTERVAL '1 second'
              )
              OR (
                COALESCE(topics.last_posted_at, topics.created_at) <
                  NOW() - :freshness_window * INTERVAL '1 second'
                AND stats.hot_score_updated_at <
                  COALESCE(topics.last_posted_at, topics.created_at) +
                    :freshness_window * INTERVAL '1 second'
              )
            )
          ORDER BY stats.hot_score_updated_at ASC NULLS FIRST,
                   topics.bumped_at DESC
          LIMIT :limit
        SQL
        archetype: Archetype.default,
        nested_by_default: SiteSetting.nested_replies_default,
        category_id: category_id,
        limit: SiteSetting.nested_replies_hot_score_batch_size,
        freshness_window: NestedReplies::HotScoreCalculator.freshness_window_seconds,
        refresh_interval: NestedReplies::HotScoreCalculator.freshness_refresh_interval_seconds,
      )
    end

    def enqueue_continuation(topic_ids, category_id: nil, drain_batch:)
      return if topic_ids.size < SiteSetting.nested_replies_hot_score_batch_size
      return if drain_batch >= MAX_DRAIN_BATCHES

      args = { drain_batch: drain_batch + 1 }
      args[:category_id] = category_id if category_id.to_i.positive?
      Jobs.enqueue(:recalculate_nested_hot_scores, args)
    end
  end
end
