# frozen_string_literal: true

module Jobs
  class BackfillNestedReplyStats < ::Jobs::Base
    cluster_concurrency 1

    BATCH_SIZE = 500

    def execute(args)
      return unless SiteSetting.nested_replies_enabled

      # Process topics in batches by ID range to avoid loading all topic IDs into memory.
      # Each job execution processes one batch of topics and re-enqueues itself for the next.
      min_topic_id = args[:from_topic_id].to_i

      topic_ids = DB.query_single(<<~SQL, min_id: min_topic_id, batch_size: BATCH_SIZE)
          SELECT id FROM topics
          WHERE id >= :min_id
            AND deleted_at IS NULL
            AND archetype = 'regular'
          ORDER BY id
          LIMIT :batch_size
        SQL

      return if topic_ids.empty?

      topic_ids.each { |topic_id| backfill_topic(topic_id) }

      next_id = topic_ids.last + 1
      Jobs.enqueue(:backfill_nested_reply_stats, from_topic_id: next_id)
    end

    private

    def backfill_topic(topic_id)
      # Single SQL statement computes both direct_reply_count and total_descendant_count
      # for all posts in a topic, then upserts into nested_view_post_stats.
      #
      # The recursive CTE walks the reply tree bottom-up to compute total_descendant_count.
      # direct_reply_count is a simple GROUP BY on reply_to_post_number.
      DB.exec(<<~SQL, topic_id: topic_id)
        WITH RECURSIVE
        -- Count direct (non-deleted) replies per parent
        direct_counts AS (
          SELECT reply_to_post_number AS parent_number, post_type,
                 COUNT(*) AS cnt
          FROM posts
          WHERE topic_id = :topic_id
            AND deleted_at IS NULL
            AND reply_to_post_number IS NOT NULL
            AND post_number > 1
          GROUP BY reply_to_post_number, post_type
        ),
        direct_agg AS (
          SELECT parent_number,
                 SUM(cnt) AS direct_reply_count,
                 SUM(CASE WHEN post_type = 4 THEN cnt ELSE 0 END) AS whisper_direct_reply_count
          FROM direct_counts
          GROUP BY parent_number
        ),
        -- Build a simple parent->child edge list for descendant counting
        edges AS (
          SELECT id, post_number, reply_to_post_number, post_type
          FROM posts
          WHERE topic_id = :topic_id
            AND deleted_at IS NULL
            AND reply_to_post_number IS NOT NULL
            AND post_number > 1
        ),
        -- Leaf nodes (posts with no children)
        leaves AS (
          SELECT e.post_number
          FROM edges e
          LEFT JOIN edges c ON c.reply_to_post_number = e.post_number
          WHERE c.post_number IS NULL
        ),
        -- Walk from each post upward, accumulating descendant counts
        -- Each post contributes 1 to every ancestor's total_descendant_count
        ancestor_walk AS (
          SELECT e.reply_to_post_number AS ancestor_number,
                 1 AS descendant_count,
                 CASE WHEN e.post_type = 4 THEN 1 ELSE 0 END AS whisper_descendant_count,
                 1 AS depth
          FROM edges e
          UNION ALL
          SELECT p.reply_to_post_number,
                 a.descendant_count + 0, -- still counts as 1 per original post
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
        -- Join with actual post IDs
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
            AND p.deleted_at IS NULL
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
          direct_reply_count = EXCLUDED.direct_reply_count,
          whisper_direct_reply_count = EXCLUDED.whisper_direct_reply_count,
          total_descendant_count = EXCLUDED.total_descendant_count,
          whisper_total_descendant_count = EXCLUDED.whisper_total_descendant_count,
          updated_at = NOW()
      SQL
    end
  end
end
