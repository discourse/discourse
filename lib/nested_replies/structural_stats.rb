# frozen_string_literal: true

module NestedReplies
  class StructuralStats
    LOCK_NAMESPACE = "nested-reply-structural-stats"
    PERSIST_BATCH_SIZE = 1000

    def self.counted_post_types
      [Post.types[:regular], Post.types[:moderator_action], Post.types[:whisper]]
    end

    def self.weights_for(post_type, action_code = nil)
      # Action-code whispers are activity records, not visible reply nodes.
      visible_whisper = post_type == Post.types[:whisper] && action_code.to_s.empty?
      counted =
        [Post.types[:regular], Post.types[:moderator_action]].include?(post_type) || visible_whisper
      [counted ? 1 : 0, visible_whisper ? 1 : 0]
    end

    def self.with_topic_lock(topic_id)
      # Exact rebuilds overwrite counters, so live deltas must land entirely
      # before or after a rebuild.
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
        rows = topic_rows(topic_id)
        calculated_stats = calculate_stats(rows)

        if calculated_stats
          persist_stats(calculated_stats)
        else
          recalculate_topic_with_recursive_sql(topic_id)
        end
      end
    end

    def self.topic_rows(topic_id)
      DB.query(<<~SQL, topic_id: topic_id)
        SELECT id, post_number, reply_to_post_number, post_type, action_code
        FROM posts
        WHERE topic_id = :topic_id
      SQL
    end
    private_class_method :topic_rows

    def self.calculate_stats(rows)
      rows_by_number = rows.index_by { |row| row.post_number.to_i }
      child_counts = Hash.new(0)
      direct_counts = Hash.new { |counts, post_number| counts[post_number] = [0, 0] }
      weights = {}

      rows.each do |row|
        post_number = row.post_number.to_i
        weights[post_number] = weights_for(row.post_type.to_i, row.action_code)
        parent_number = row.reply_to_post_number&.to_i
        next unless rows_by_number.key?(parent_number)

        child_counts[parent_number] += 1
        direct_counts[parent_number][0] += weights[post_number][0]
        direct_counts[parent_number][1] += weights[post_number][1]
      end

      subtree_counts = weights.transform_values(&:dup)
      leaf_numbers = rows_by_number.keys.select { |post_number| child_counts[post_number].zero? }
      processed_count = 0
      leaf_index = 0

      # Fold each subtree into its parent once, keeping valid trees O(N).
      while leaf_index < leaf_numbers.length
        post_number = leaf_numbers[leaf_index]
        leaf_index += 1
        processed_count += 1

        row = rows_by_number[post_number]
        parent_number = row.reply_to_post_number&.to_i
        next unless rows_by_number.key?(parent_number)

        subtree_counts[parent_number][0] += subtree_counts[post_number][0]
        subtree_counts[parent_number][1] += subtree_counts[post_number][1]
        child_counts[parent_number] -= 1
        leaf_numbers << parent_number if child_counts[parent_number].zero?
      end

      return if processed_count != rows.length

      rows.map do |stat_row|
        post_number = stat_row.post_number.to_i
        own_total, own_whisper = weights[post_number]
        direct_total, direct_whisper = direct_counts[post_number]
        subtree_total, subtree_whisper = subtree_counts[post_number]

        [
          stat_row.id.to_i,
          post_number,
          direct_total,
          subtree_total - own_total,
          direct_whisper,
          subtree_whisper - own_whisper,
        ]
      end
    end
    private_class_method :calculate_stats

    def self.persist_stats(calculated_stats)
      calculated_stats.each_slice(PERSIST_BATCH_SIZE) { |batch| persist_stats_batch(batch) }
    end
    private_class_method :persist_stats

    def self.persist_stats_batch(calculated_stats)
      return if calculated_stats.empty?

      post_ids,
      post_numbers,
      direct_reply_counts,
      total_descendant_counts,
      whisper_direct_reply_counts,
      whisper_total_descendant_counts =
        calculated_stats.transpose

      DB.exec(
        <<~SQL,
          INSERT INTO nested_view_post_stats (
            post_id,
            direct_reply_count,
            total_descendant_count,
            whisper_direct_reply_count,
            whisper_total_descendant_count,
            structural_backfilled_at,
            created_at,
            updated_at
          )
          SELECT updates.post_id,
                 updates.direct_reply_count,
                 updates.total_descendant_count,
                 updates.whisper_direct_reply_count,
                 updates.whisper_total_descendant_count,
                 CASE WHEN updates.post_number = 1 THEN clock_timestamp() END,
                 NOW(),
                 NOW()
          FROM UNNEST(
            ARRAY[:post_ids]::bigint[],
            ARRAY[:post_numbers]::integer[],
            ARRAY[:direct_reply_counts]::integer[],
            ARRAY[:total_descendant_counts]::integer[],
            ARRAY[:whisper_direct_reply_counts]::integer[],
            ARRAY[:whisper_total_descendant_counts]::integer[]
          ) AS updates(
            post_id,
            post_number,
            direct_reply_count,
            total_descendant_count,
            whisper_direct_reply_count,
            whisper_total_descendant_count
          )
          ON CONFLICT (post_id) DO UPDATE SET
            direct_reply_count = EXCLUDED.direct_reply_count,
            total_descendant_count = EXCLUDED.total_descendant_count,
            whisper_direct_reply_count = EXCLUDED.whisper_direct_reply_count,
            whisper_total_descendant_count = EXCLUDED.whisper_total_descendant_count,
            structural_backfilled_at = COALESCE(
              EXCLUDED.structural_backfilled_at,
              nested_view_post_stats.structural_backfilled_at
            ),
            updated_at = NOW()
        SQL
        post_ids: post_ids,
        post_numbers: post_numbers,
        direct_reply_counts: direct_reply_counts,
        total_descendant_counts: total_descendant_counts,
        whisper_direct_reply_counts: whisper_direct_reply_counts,
        whisper_total_descendant_counts: whisper_total_descendant_counts,
      )
    end
    private_class_method :persist_stats_batch

    def self.recalculate_topic_with_recursive_sql(topic_id)
      regular = Post.types[:regular]
      moderator_action = Post.types[:moderator_action]
      whisper = Post.types[:whisper]
      counted_post_sql =
        "post_type IN (#{regular}, #{moderator_action}) OR " \
          "(post_type = #{whisper} AND COALESCE(action_code, '') = '')"
      whisper_post_sql = "post_type = #{whisper} AND COALESCE(action_code, '') = ''"

      DB.exec(<<~SQL, topic_id: topic_id)
          WITH RECURSIVE
          edges AS (
            SELECT post_number, reply_to_post_number, post_type, action_code
            FROM posts
            WHERE topic_id = :topic_id
              AND reply_to_post_number IS NOT NULL
              AND post_number > 1
          ),
          direct_agg AS (
            SELECT reply_to_post_number AS parent_number,
                   COUNT(*) FILTER (WHERE #{counted_post_sql}) AS direct_reply_count,
                   COUNT(*) FILTER (WHERE #{whisper_post_sql}) AS whisper_direct_reply_count
            FROM edges
            GROUP BY reply_to_post_number
          ),
          ancestor_walk AS (
            SELECT edges.reply_to_post_number AS ancestor_number,
                   CASE WHEN #{counted_post_sql} THEN 1 ELSE 0 END AS descendant_count,
                   CASE WHEN #{whisper_post_sql} THEN 1 ELSE 0 END AS whisper_descendant_count,
                   ARRAY[edges.post_number, edges.reply_to_post_number]::integer[] AS path
            FROM edges

            UNION ALL

            SELECT parents.reply_to_post_number,
                   ancestor_walk.descendant_count,
                   ancestor_walk.whisper_descendant_count,
                   ancestor_walk.path || parents.reply_to_post_number
            FROM ancestor_walk
            JOIN edges parents ON parents.post_number = ancestor_walk.ancestor_number
            WHERE NOT parents.reply_to_post_number = ANY(ancestor_walk.path)
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
                 CASE WHEN post_number = 1 THEN clock_timestamp() END,
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
    end
    private_class_method :recalculate_topic_with_recursive_sql
  end
end
