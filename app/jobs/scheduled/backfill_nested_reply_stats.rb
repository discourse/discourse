# frozen_string_literal: true

module Jobs
  class BackfillNestedReplyStats < ::Jobs::Scheduled
    every 5.minutes

    cluster_concurrency 1

    def execute(_ = nil)
      return unless SiteSetting.nested_replies_enabled

      topic_ids =
        DB.query_single(<<~SQL, batch_size: SiteSetting.nested_replies_backfill_batch_size)
          SELECT t.id FROM topics t
          INNER JOIN nested_topics nt ON nt.topic_id = t.id
          LEFT JOIN nested_view_post_stats s ON s.post_id = (
            SELECT p.id FROM posts p
            WHERE p.topic_id = t.id AND p.post_number = 1
            LIMIT 1
          )
          WHERE t.deleted_at IS NULL
            AND t.archetype = 'regular'
            AND s.post_id IS NULL
          ORDER BY t.id DESC
          LIMIT :batch_size
        SQL

      return if topic_ids.empty?

      topic_ids.each do |topic_id|
        backfill_topic(topic_id)
        ensure_op_stat_row(topic_id)
      end
    end

    private

    # Guarantees the OP has a stats row so the selector (which keys on
    # s.post_id IS NULL for post_number = 1) will not re-pick this topic
    # on the next run when it has no qualifying replies. When a reply later
    # arrives, nested_replies_increment_stats upserts into the same row.
    def ensure_op_stat_row(topic_id)
      DB.exec(<<~SQL, topic_id: topic_id)
        INSERT INTO nested_view_post_stats
          (post_id, direct_reply_count, whisper_direct_reply_count,
           total_descendant_count, whisper_total_descendant_count,
           created_at, updated_at)
        SELECT p.id, 0, 0, 0, 0, NOW(), NOW()
        FROM posts p
        WHERE p.topic_id = :topic_id AND p.post_number = 1
        ON CONFLICT (post_id) DO NOTHING
      SQL
    end

    def backfill_topic(topic_id)
      DB.exec(<<~SQL, topic_id: topic_id, whisper_type: Post.types[:whisper])
        WITH RECURSIVE
        direct_counts AS (
          SELECT reply_to_post_number AS parent_number, post_type,
                 COUNT(*) AS cnt
          FROM posts
          WHERE topic_id = :topic_id
            AND reply_to_post_number IS NOT NULL
            AND post_number > 1
          GROUP BY reply_to_post_number, post_type
        ),
        direct_agg AS (
          SELECT parent_number,
                 SUM(cnt) AS direct_reply_count,
                 SUM(CASE WHEN post_type = :whisper_type THEN cnt ELSE 0 END) AS whisper_direct_reply_count
          FROM direct_counts
          GROUP BY parent_number
        ),
        edges AS (
          SELECT id, post_number, reply_to_post_number, post_type
          FROM posts
          WHERE topic_id = :topic_id
            AND reply_to_post_number IS NOT NULL
            AND post_number > 1
        ),
        ancestor_walk AS (
          SELECT e.reply_to_post_number AS ancestor_number,
                 1 AS descendant_count,
                 CASE WHEN e.post_type = :whisper_type THEN 1 ELSE 0 END AS whisper_descendant_count,
                 1 AS depth
          FROM edges e
          UNION ALL
          SELECT p.reply_to_post_number,
                 a.descendant_count,
                 a.whisper_descendant_count,
                 a.depth + 1
          FROM ancestor_walk a
          JOIN edges p ON p.post_number = a.ancestor_number
          WHERE a.depth < 500
        ),
        descendant_agg AS (
          SELECT ancestor_number,
                 COUNT(*) AS total_descendant_count,
                 SUM(whisper_descendant_count) AS whisper_total_descendant_count
          FROM ancestor_walk
          GROUP BY ancestor_number
        ),
        combined AS (
          SELECT p.id AS post_id,
                 COALESCE(d.direct_reply_count, 0) AS direct_reply_count,
                 COALESCE(d.whisper_direct_reply_count, 0) AS whisper_direct_reply_count,
                 COALESCE(t.total_descendant_count, 0) AS total_descendant_count,
                 COALESCE(t.whisper_total_descendant_count, 0) AS whisper_total_descendant_count
          FROM posts p
          LEFT JOIN direct_agg d ON d.parent_number = p.post_number
          LEFT JOIN descendant_agg t ON t.ancestor_number = p.post_number
          WHERE p.topic_id = :topic_id
            AND (d.parent_number IS NOT NULL OR t.ancestor_number IS NOT NULL)
        )
        INSERT INTO nested_view_post_stats
          (post_id, direct_reply_count, whisper_direct_reply_count,
           total_descendant_count, whisper_total_descendant_count,
           created_at, updated_at)
        SELECT post_id, direct_reply_count, whisper_direct_reply_count,
               total_descendant_count, whisper_total_descendant_count,
               NOW(), NOW()
        FROM combined
        ON CONFLICT (post_id) DO UPDATE SET
          direct_reply_count = GREATEST(EXCLUDED.direct_reply_count, nested_view_post_stats.direct_reply_count),
          whisper_direct_reply_count = GREATEST(EXCLUDED.whisper_direct_reply_count, nested_view_post_stats.whisper_direct_reply_count),
          total_descendant_count = GREATEST(EXCLUDED.total_descendant_count, nested_view_post_stats.total_descendant_count),
          whisper_total_descendant_count = GREATEST(EXCLUDED.whisper_total_descendant_count, nested_view_post_stats.whisper_total_descendant_count),
          updated_at = NOW()
      SQL
    end
  end
end
