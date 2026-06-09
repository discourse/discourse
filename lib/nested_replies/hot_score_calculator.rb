# frozen_string_literal: true

module NestedReplies
  class HotScoreCalculator
    BUCKETS = [
      [10, 14.days],
      [50, 7.days],
      [250, 3.days],
      [1000, 36.hours],
      [Float::INFINITY, 12.hours],
    ].freeze

    ENGAGEMENT_WEIGHTS = {
      reply_count: 5.0,
      like_score: 15.0,
      incoming_link_count: 5.0,
      bookmark_count: 2.0,
      reads: 0.2,
    }.freeze

    def self.engagement_score_sql(table_name)
      ENGAGEMENT_WEIGHTS.map do |column, weight|
        "COALESCE(#{table_name}.#{column}, 0) * #{weight}"
      end.join(" + ")
    end

    def self.time_scale_seconds(sibling_count)
      count = sibling_count.to_i
      BUCKETS.find { |max_count, _| count <= max_count }.second.to_i
    end

    def self.recalculate_for_post(post_id)
      DB.exec(<<~SQL, post_id: post_id)
        WITH target AS (
          SELECT p.*,
                 COUNT(siblings.id) AS sibling_count
          FROM posts p
          JOIN posts siblings ON siblings.topic_id = p.topic_id
            AND siblings.reply_to_post_number IS NOT DISTINCT FROM p.reply_to_post_number
            AND siblings.post_number > 1
          WHERE p.id = :post_id
          GROUP BY p.id
        )
        INSERT INTO nested_view_post_stats
          (post_id, hot_score, hot_score_updated_at, topic_id, reply_to_post_number, post_number, created_at, updated_at)
        SELECT target.id,
               LN(1 + GREATEST(#{engagement_score_sql("target")}, 0)) +
                 EXTRACT(EPOCH FROM target.created_at) /
                   CASE
                     WHEN target.sibling_count <= 10 THEN #{14.days.to_i}
                     WHEN target.sibling_count <= 50 THEN #{7.days.to_i}
                     WHEN target.sibling_count <= 250 THEN #{3.days.to_i}
                     WHEN target.sibling_count <= 1000 THEN #{36.hours.to_i}
                     ELSE #{12.hours.to_i}
                   END,
               NOW(),
               target.topic_id,
               target.reply_to_post_number,
               target.post_number,
               NOW(),
               NOW()
        FROM target
        ON CONFLICT (post_id) DO UPDATE SET
          hot_score = EXCLUDED.hot_score,
          hot_score_updated_at = EXCLUDED.hot_score_updated_at,
          topic_id = EXCLUDED.topic_id,
          reply_to_post_number = EXCLUDED.reply_to_post_number,
          post_number = EXCLUDED.post_number,
          updated_at = NOW()
      SQL
    end

    def self.recalculate_siblings_for_post(post)
      return if post.blank?

      recalculate_for_sibling_group(
        topic_id: post.topic_id,
        reply_to_post_number: post.reply_to_post_number,
      )
    end

    def self.recalculate_for_sibling_group(topic_id:, reply_to_post_number:)
      sibling_count =
        Post
          .with_deleted
          .where(topic_id: topic_id, reply_to_post_number: reply_to_post_number)
          .where("post_number > 1")
          .count
      time_scale_seconds = time_scale_seconds(sibling_count)

      DB.exec(
        <<~SQL,
          INSERT INTO nested_view_post_stats
            (post_id, hot_score, hot_score_updated_at, topic_id, reply_to_post_number, post_number, created_at, updated_at)
          SELECT p.id,
                 LN(1 + GREATEST(#{engagement_score_sql("p")}, 0)) +
                   EXTRACT(EPOCH FROM p.created_at) / :time_scale_seconds,
                 NOW(),
                 p.topic_id,
                 p.reply_to_post_number,
                 p.post_number,
                 NOW(),
                 NOW()
          FROM posts p
          WHERE p.topic_id = :topic_id
            AND p.reply_to_post_number IS NOT DISTINCT FROM :reply_to_post_number
            AND p.post_number > 1
          ON CONFLICT (post_id) DO UPDATE SET
            hot_score = EXCLUDED.hot_score,
            hot_score_updated_at = EXCLUDED.hot_score_updated_at,
            topic_id = EXCLUDED.topic_id,
            reply_to_post_number = EXCLUDED.reply_to_post_number,
            post_number = EXCLUDED.post_number,
            updated_at = NOW()
        SQL
        topic_id: topic_id,
        reply_to_post_number: reply_to_post_number,
        time_scale_seconds: time_scale_seconds,
      )
    end
  end
end
