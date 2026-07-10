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
              stats.hot_score_updated_at IS NULL OR
              stats.hot_score_updated_at < NOW() - INTERVAL '7 days'
            )
          ORDER BY stats.hot_score_updated_at ASC NULLS FIRST,
                   topics.bumped_at DESC
          LIMIT :limit
        SQL
        nested_by_default: SiteSetting.nested_replies_default,
        limit: SiteSetting.nested_replies_backfill_batch_size,
      )
    end
  end
end
