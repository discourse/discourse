# frozen_string_literal: true

module Jobs
  class RecalculateNestedHotScores < ::Jobs::Scheduled
    # Hot scores are primarily maintained by event hooks on post create,
    # destroy/reparent, and like/unlike. This job is only a safety net for
    # missed events or score components that change outside those hooks.
    every 1.day

    def execute(_args)
      return unless SiteSetting.nested_replies_enabled

      topic_ids = DB.query_single(<<~SQL, limit: SiteSetting.nested_replies_backfill_batch_size)
            SELECT nt.topic_id
            FROM nested_topics nt
            WHERE EXISTS (
              SELECT 1
              FROM posts p
              LEFT JOIN nested_view_post_stats s ON s.post_id = p.id
              WHERE p.topic_id = nt.topic_id
                AND p.post_number > 1
                AND (
                  s.post_id IS NULL OR
                  s.hot_score_updated_at IS NULL OR
                  (s.thread_hot_score <= 0 AND s.hot_score > 0) OR
                  (s.relative_thread_hot_score <= 0 AND s.relative_hot_score > 0) OR
                  (s.relative_hot_score <= 0 AND s.hot_score > 0) OR
                  s.topic_id IS NULL OR
                  s.reply_to_post_number IS DISTINCT FROM p.reply_to_post_number OR
                  s.post_number IS DISTINCT FROM p.post_number OR
                  s.hot_score_updated_at < NOW() - INTERVAL '7 days'
                )
            )
            ORDER BY nt.updated_at DESC
            LIMIT :limit
          SQL
      topic_ids.each { |topic_id| recalculate_topic(topic_id) }
    end

    private

    def recalculate_topic(topic_id)
      parent_numbers =
        Post
          .with_deleted
          .where(topic_id: topic_id)
          .where("post_number > 1")
          .distinct
          .pluck(:reply_to_post_number)
          .map do |reply_to_post_number|
            if NestedReplies::HotScoreCalculator.root_sibling_group?(reply_to_post_number)
              nil
            else
              reply_to_post_number
            end
          end
          .uniq

      parent_numbers.each do |reply_to_post_number|
        NestedReplies::HotScoreCalculator.recalculate_for_sibling_group(
          topic_id: topic_id,
          reply_to_post_number: reply_to_post_number,
        )
      end
    end
  end
end
