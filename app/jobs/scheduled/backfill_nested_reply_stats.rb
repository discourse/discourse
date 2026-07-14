# frozen_string_literal: true

module Jobs
  class BackfillNestedReplyStats < ::Jobs::Scheduled
    every 5.minutes

    cluster_concurrency 1

    def execute(args = {})
      return unless SiteSetting.nested_replies_enabled

      args ||= {}
      topic_ids = topic_ids_missing_stats(category_id: args[:category_id])
      return if topic_ids.empty?

      topic_ids.each { |topic_id| backfill_topic(topic_id) }
    end

    private

    def topic_ids_missing_stats(category_id: nil)
      category_id = category_id.to_i
      category_filter = category_id.positive? ? "AND t.category_id = :category_id" : ""

      DB.query_single(
        <<~SQL,
          SELECT t.id
          FROM topics t
          LEFT JOIN nested_topics nt ON nt.topic_id = t.id
          INNER JOIN posts op ON op.topic_id = t.id AND op.post_number = 1
          LEFT JOIN nested_view_post_stats s ON s.post_id = op.id
          WHERE t.deleted_at IS NULL
            AND t.archetype = :archetype
            AND (:nested_replies_default OR nt.topic_id IS NOT NULL)
            #{category_filter}
            AND (
              s.post_id IS NULL
              OR EXISTS (
                SELECT 1
                FROM posts child
                INNER JOIN posts parent
                  ON parent.topic_id = child.topic_id
                 AND parent.post_number = child.reply_to_post_number
                LEFT JOIN nested_view_post_stats parent_stats
                  ON parent_stats.post_id = parent.id
                WHERE child.topic_id = t.id
                  AND child.reply_to_post_number IS NOT NULL
                  AND child.post_number > 1
                  AND parent_stats.post_id IS NULL
              )
            )
          ORDER BY t.id DESC
          LIMIT :batch_size
        SQL
        archetype: Archetype.default,
        batch_size: SiteSetting.nested_replies_backfill_batch_size,
        category_id: category_id,
        nested_replies_default: SiteSetting.nested_replies_default,
      )
    end

    def backfill_topic(topic_id)
      DB.exec(<<~SQL, topic_id: topic_id, whisper_type: Post.types[:whisper])
        WITH RECURSIVE
        edges AS (
          SELECT post_number, reply_to_post_number, post_type
          FROM posts
          WHERE topic_id = :topic_id
            AND reply_to_post_number IS NOT NULL
            AND post_number > 1
        ),
        direct_counts AS (
          SELECT reply_to_post_number AS parent_number, post_type,
                 COUNT(*) AS cnt
          FROM edges
          GROUP BY reply_to_post_number, post_type
        ),
        direct_agg AS (
          SELECT parent_number,
                 SUM(cnt) AS direct_reply_count,
                 SUM(CASE WHEN post_type = :whisper_type THEN cnt ELSE 0 END) AS whisper_direct_reply_count
          FROM direct_counts
          GROUP BY parent_number
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
            AND (p.post_number = 1 OR d.parent_number IS NOT NULL OR t.ancestor_number IS NOT NULL)
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
