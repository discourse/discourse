# frozen_string_literal: true

module Jobs
  class RecalculateNestedHotScores < ::Jobs::Scheduled
    every 5.minutes

    cluster_concurrency 1

    def execute(args)
      return unless SiteSetting.nested_replies_enabled

      if args&.dig(:topic_id)
        NestedReplies::HotScoreCalculator.recalculate_topic(args[:topic_id])
        return
      end

      stale_topic_ids.each do |topic_id|
        NestedReplies::HotScoreCalculator.recalculate_topic(topic_id)
      end
    end

    private

    def stale_topic_ids
      DB.query_single(
        <<~SQL,
          SELECT topics.id
          FROM topics
          JOIN posts original_post ON original_post.topic_id = topics.id
            AND original_post.post_number = 1
          LEFT JOIN nested_topics ON nested_topics.topic_id = topics.id
          LEFT JOIN nested_view_post_stats stats ON stats.post_id = original_post.id
          WHERE topics.deleted_at IS NULL
            AND topics.archetype = 'regular'
            AND (:nested_by_default OR nested_topics.topic_id IS NOT NULL)
            AND stats.structural_backfilled_at IS NOT NULL
            AND EXISTS (
              SELECT 1
              FROM posts replies
              WHERE replies.topic_id = topics.id
                AND replies.post_number > 1
                AND replies.post_type IN (#{NestedReplies::HotScoreCalculator.public_post_types.join(", ")})
            )
            AND (
              stats.hot_score_updated_at IS NULL
              OR NOT EXISTS (
                SELECT 1
                FROM topic_custom_fields formula_version
                WHERE formula_version.topic_id = topics.id
                  AND formula_version.name = :formula_version_field
                  AND formula_version.value = :formula_version
              )
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
        nested_by_default: SiteSetting.nested_replies_default,
        limit: SiteSetting.nested_replies_backfill_batch_size,
        formula_version_field: NestedReplies::HotScoreCalculator::FORMULA_VERSION_FIELD,
        formula_version: NestedReplies::HotScoreCalculator::FORMULA_VERSION.to_s,
        freshness_window: NestedReplies::HotScoreCalculator.freshness_window_seconds,
        refresh_interval: NestedReplies::HotScoreCalculator.freshness_refresh_interval_seconds,
      )
    end
  end
end
