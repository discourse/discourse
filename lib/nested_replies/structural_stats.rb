# frozen_string_literal: true

module NestedReplies
  class StructuralStats
    LOCK_NAMESPACE = "nested-reply-structural-stats"

    def self.counted_post_types
      [Post.types[:regular], Post.types[:moderator_action], Post.types[:whisper]]
    end

    def self.weights_for(post_type)
      [counted_post_types.include?(post_type) ? 1 : 0, post_type == Post.types[:whisper] ? 1 : 0]
    end

    def self.with_topic_lock(topic_id)
      # Exact rebuilds overwrite counters, so live deltas must share this
      # transaction lock to ensure they land entirely before or after a rebuild.
      NestedViewPostStat.transaction do
        DB.query_single(
          "SELECT pg_advisory_xact_lock(hashtextextended(:lock_name, 0))",
          lock_name: "#{LOCK_NAMESPACE}:#{topic_id}",
        )
        yield
      end
    end

    def self.recalculate_topic(topic_id)
      return if topic_id.blank?

      with_topic_lock(topic_id) do
        DB.exec(
          <<~SQL,
            WITH RECURSIVE
            edges AS (
              SELECT post_number, reply_to_post_number, post_type
              FROM posts
              WHERE topic_id = :topic_id
                AND reply_to_post_number IS NOT NULL
                AND post_number > 1
            ),
            direct_agg AS (
              SELECT reply_to_post_number AS parent_number,
                     COUNT(*) FILTER (
                       WHERE post_type = ANY(ARRAY[:counted_post_types]::integer[])
                     ) AS direct_reply_count,
                     COUNT(*) FILTER (
                       WHERE post_type = :whisper_type
                     ) AS whisper_direct_reply_count
              FROM edges
              GROUP BY reply_to_post_number
            ),
            ancestor_walk AS (
              SELECT edges.reply_to_post_number AS ancestor_number,
                     CASE
                       WHEN edges.post_type = ANY(ARRAY[:counted_post_types]::integer[]) THEN 1
                       ELSE 0
                     END AS descendant_count,
                     CASE WHEN edges.post_type = :whisper_type THEN 1 ELSE 0 END AS whisper_descendant_count,
                     1 AS depth,
                     ARRAY[edges.post_number, edges.reply_to_post_number]::integer[] AS path
              FROM edges

              UNION ALL

              SELECT parents.reply_to_post_number,
                     ancestor_walk.descendant_count,
                     ancestor_walk.whisper_descendant_count,
                     ancestor_walk.depth + 1,
                     ancestor_walk.path || parents.reply_to_post_number
              FROM ancestor_walk
              JOIN edges parents ON parents.post_number = ancestor_walk.ancestor_number
              WHERE ancestor_walk.depth < 500
                AND NOT parents.reply_to_post_number = ANY(ancestor_walk.path)
            ),
            descendant_agg AS (
              SELECT ancestor_number,
                     SUM(descendant_count) AS total_descendant_count,
                     SUM(whisper_descendant_count) AS whisper_total_descendant_count
              FROM ancestor_walk
              GROUP BY ancestor_number
            ),
            calculated AS (
              SELECT posts.id AS post_id,
                     posts.post_number,
                     COALESCE(direct_agg.direct_reply_count, 0) AS direct_reply_count,
                     COALESCE(direct_agg.whisper_direct_reply_count, 0) AS whisper_direct_reply_count,
                     COALESCE(descendant_agg.total_descendant_count, 0) AS total_descendant_count,
                     COALESCE(descendant_agg.whisper_total_descendant_count, 0) AS whisper_total_descendant_count
              FROM posts
              LEFT JOIN direct_agg ON direct_agg.parent_number = posts.post_number
              LEFT JOIN descendant_agg ON descendant_agg.ancestor_number = posts.post_number
              WHERE posts.topic_id = :topic_id
            )
            INSERT INTO nested_view_post_stats (
              post_id,
              direct_reply_count,
              whisper_direct_reply_count,
              total_descendant_count,
              whisper_total_descendant_count,
              structural_backfilled_at,
              created_at,
              updated_at
            )
            SELECT post_id,
                   direct_reply_count,
                   whisper_direct_reply_count,
                   total_descendant_count,
                   whisper_total_descendant_count,
                   CASE WHEN post_number = 1 THEN NOW() END,
                   NOW(),
                   NOW()
            FROM calculated
            ON CONFLICT (post_id) DO UPDATE SET
              direct_reply_count = EXCLUDED.direct_reply_count,
              whisper_direct_reply_count = EXCLUDED.whisper_direct_reply_count,
              total_descendant_count = EXCLUDED.total_descendant_count,
              whisper_total_descendant_count = EXCLUDED.whisper_total_descendant_count,
              structural_backfilled_at = COALESCE(
                EXCLUDED.structural_backfilled_at,
                nested_view_post_stats.structural_backfilled_at
              ),
              updated_at = NOW()
          SQL
          topic_id: topic_id,
          counted_post_types: counted_post_types,
          whisper_type: Post.types[:whisper],
        )
      end
    end
  end
end
