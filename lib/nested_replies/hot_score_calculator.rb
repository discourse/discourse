# frozen_string_literal: true

module NestedReplies
  class HotScoreCalculator
    HOT_SCORE_FLOOR = 0.0
    LIKE_WEIGHT = 1.0
    REPLY_WEIGHT = 2.0
    FRESHNESS_MAX_BONUS = 3.0
    FRESHNESS_HALF_LIFE_SECONDS = 7.days.to_f
    FRESHNESS_REFRESH_INTERVAL_SECONDS = 6.hours.to_i
    FRESHNESS_CUTOFF_HALF_LIVES = 8
    CHILD_PENALTY = 0.25
    LOCK_VALIDITY_SECONDS = 5.minutes.to_i
    PERSIST_BATCH_SIZE = 1000

    def self.freshness_max_bonus
      FRESHNESS_MAX_BONUS
    end

    def self.freshness_half_life_seconds
      FRESHNESS_HALF_LIFE_SECONDS
    end

    def self.freshness_refresh_interval_seconds
      FRESHNESS_REFRESH_INTERVAL_SECONDS
    end

    def self.freshness_window_seconds
      FRESHNESS_HALF_LIFE_SECONDS * FRESHNESS_CUTOFF_HALF_LIVES
    end

    def self.child_penalty
      CHILD_PENALTY
    end

    def self.public_post_types
      [Post.types[:regular], Post.types[:moderator_action]]
    end

    def self.public_post_sql(table_name)
      <<~SQL.squish
        #{table_name}.post_type IN (#{public_post_types.join(", ")})
        AND #{table_name}.deleted_at IS NULL
        AND NOT #{table_name}.hidden
        AND NOT #{table_name}.user_deleted
      SQL
    end

    def self.hot_score_sql(table_name, reply_count_sql: "0")
      engagement_sql =
        "COALESCE(#{table_name}.like_score, 0) * #{LIKE_WEIGHT} + " \
          "COALESCE(#{reply_count_sql}, 0) * #{REPLY_WEIGHT}"
      age_seconds_sql =
        "GREATEST(EXTRACT(EPOCH FROM CURRENT_TIMESTAMP - #{table_name}.created_at), 0)"
      freshness_sql =
        "#{freshness_max_bonus} * " \
          "POWER(0.5, #{age_seconds_sql} / #{freshness_half_life_seconds})"

      <<~SQL.squish
        CASE
          WHEN #{public_post_sql(table_name)}
          THEN LN(1 + GREATEST(#{engagement_sql}, 0)) + #{freshness_sql}
          ELSE #{HOT_SCORE_FLOOR}
        END
      SQL
    end

    def self.fallback_hot_score_sql(table_name)
      reply_count_sql = <<~SQL.squish
        (
          SELECT COUNT(*)
          FROM posts nested_hot_direct_replies
          WHERE nested_hot_direct_replies.topic_id = #{table_name}.topic_id
            AND nested_hot_direct_replies.reply_to_post_number = #{table_name}.post_number
            AND nested_hot_direct_replies.post_number > 1
            AND #{public_post_sql("nested_hot_direct_replies")}
        )
      SQL

      hot_score_sql(table_name, reply_count_sql: reply_count_sql)
    end

    def self.score_for(post, direct_reply_count: 0, now: Time.current)
      return HOT_SCORE_FLOOR unless public_post?(post)

      engagement = post.like_score.to_f * LIKE_WEIGHT + direct_reply_count.to_f * REPLY_WEIGHT
      age_seconds = [now.to_f - post.created_at.to_f, 0.0].max
      freshness = freshness_max_bonus * 0.5**(age_seconds / freshness_half_life_seconds)
      Math.log(1 + [engagement, 0.0].max) + freshness
    end

    def self.persisted_score_stale_sql(
      stats_table = "nested_view_post_stats",
      topic_stats_table: nil
    )
      conditions = [StatsFreshness.stale_sql("#{stats_table}.hot_score_updated_at")]
      if topic_stats_table
        conditions << StatsFreshness.stale_sql("#{topic_stats_table}.hot_score_updated_at")
      end
      conditions.join(" OR ")
    end

    def self.public_post?(post)
      public_post_types.include?(post.post_type) && post.deleted_at.nil? && !post.hidden? &&
        !post.user_deleted?
    end

    def self.recalculate_for_post_if_nested(post_id)
      post = Post.with_deleted.includes(topic: :nested_topic).find_by(id: post_id)
      return if post.blank? || post.post_number == 1 || !public_post_types.include?(post.post_type)
      return unless post.topic&.nested_view?

      recalculate_for_post(post.id)
    end

    def self.recalculate_after_post_destroyed(post)
      return if post.blank? || post.post_number == 1 || !public_post_types.include?(post.post_type)
      return unless post.topic&.nested_view?

      with_topic_lock(post.topic_id) do
        if Post.with_deleted.exists?(id: post.id)
          recalculate_for_post_without_lock(post.id)
        else
          recalculate_for_post_number_without_lock(
            topic_id: post.topic_id,
            post_number: post.reply_to_post_number,
          )
        end
      end
    end

    def self.recalculate_after_reparent(post, previous_reply_to_post_number)
      return if post.blank? || post.post_number == 1
      return unless post.topic&.nested_view?

      with_topic_lock(post.topic_id) do
        recalculate_for_post_without_lock(post.id)
        recalculate_for_post_number_without_lock(
          topic_id: post.topic_id,
          post_number: previous_reply_to_post_number,
        )
      end
    end

    def self.recalculate_after_visibility_change(post)
      return if post.blank? || post.post_number == 1
      return unless post.topic&.nested_view?

      recalculate_for_post(post.id)
    end

    def self.recalculate_for_post_number(topic_id:, post_number:)
      return if post_number.blank? || post_number == 1

      with_topic_lock(topic_id) do
        recalculate_for_post_number_without_lock(topic_id: topic_id, post_number: post_number)
      end
    end

    def self.recalculate_for_post(post_id)
      return if post_id.blank?

      topic_id = Post.with_deleted.where(id: post_id).pick(:topic_id)
      return if topic_id.blank?

      with_topic_lock(topic_id) { recalculate_for_post_without_lock(post_id) }
    end

    def self.recalculate_posts_for_topic(topic_id, post_ids)
      post_ids = post_ids.compact.uniq
      return if topic_id.blank? || post_ids.empty?

      with_topic_lock(topic_id) do
        post_ids.each { |post_id| recalculate_for_post_without_lock(post_id) }
      end
    end

    def self.recalculate_topic(topic_id)
      return if topic_id.blank?

      with_topic_lock(topic_id) { recalculate_topic_without_lock(topic_id) }
    end

    def self.with_topic_lock(topic_id, &block)
      DB.after_commit do
        DistributedMutex.synchronize(
          "nested_hot_scores_topic_#{topic_id}",
          validity: LOCK_VALIDITY_SECONDS,
          &block
        )
      end
    end

    def self.recalculate_for_post_number_without_lock(topic_id:, post_number:)
      return if post_number.blank? || post_number == 1

      post_id = Post.with_deleted.where(topic_id: topic_id, post_number: post_number).pick(:id)
      recalculate_for_post_without_lock(post_id) if post_id
    end

    def self.recalculate_for_post_without_lock(post_id)
      path = score_path(post_id)
      return if path.empty?

      child_thread_hot_score = nil
      child_branch_is_public = false
      scores =
        path.map do |post|
          thread_hot_score = post.hot_score.to_f
          branch_is_public = public_post_types.include?(post.post_type)
          if branch_is_public
            thread_hot_score = [
              thread_hot_score,
              post.other_child_thread_hot_score.to_f - child_penalty,
            ].max if post.other_child_thread_hot_score
            if child_thread_hot_score && child_branch_is_public
              thread_hot_score = [thread_hot_score, child_thread_hot_score - child_penalty].max
            end
          end
          child_thread_hot_score = thread_hot_score
          child_branch_is_public = branch_is_public

          [post.post_id, post.hot_score.to_f, thread_hot_score]
        end

      persist_scores(scores)
    end

    def self.recalculate_topic_without_lock(topic_id)
      NestedViewPostStat.transaction do
        reset_topic_scores(topic_id)
        propagate_topic_scores(topic_id)
        mark_topic_recalculated(topic_id)
      end
    end

    def self.score_path(post_id)
      DB.query(<<~SQL, post_id: post_id)
          WITH RECURSIVE path AS (
            SELECT posts.id AS post_id,
                   posts.topic_id,
                   posts.post_number,
                   posts.reply_to_post_number,
                   posts.post_type,
                   posts.deleted_at,
                   posts.hidden,
                   posts.user_deleted,
                   posts.like_score,
                   posts.created_at,
                   NULL::integer AS path_child_post_number,
                   0 AS depth,
                   ARRAY[posts.post_number]::integer[] AS path
            FROM posts
            WHERE posts.id = :post_id
              AND posts.post_number > 1

            UNION ALL

            SELECT parent.id,
                   parent.topic_id,
                   parent.post_number,
                   parent.reply_to_post_number,
                   parent.post_type,
                   parent.deleted_at,
                   parent.hidden,
                   parent.user_deleted,
                   parent.like_score,
                   parent.created_at,
                   path.post_number,
                   path.depth + 1,
                   path.path || parent.post_number
            FROM path
            JOIN posts parent ON parent.topic_id = path.topic_id
              AND parent.post_number = path.reply_to_post_number
            WHERE parent.post_number > 1
              AND NOT parent.post_number = ANY(path.path)
          )
          SELECT path.post_id,
                 path.depth,
                 path.post_type,
                 #{hot_score_sql("path", reply_count_sql: "public_replies.reply_count")} AS hot_score,
                 other_children.thread_hot_score AS other_child_thread_hot_score
          FROM path
          LEFT JOIN LATERAL (
            SELECT COUNT(*) AS reply_count
            FROM posts replies
            WHERE replies.topic_id = path.topic_id
              AND replies.reply_to_post_number = path.post_number
              AND replies.post_number > 1
              AND #{public_post_sql("replies")}
          ) public_replies ON TRUE
          LEFT JOIN LATERAL (
            SELECT MAX(child_stats.thread_hot_score) AS thread_hot_score
            FROM posts children
            JOIN nested_view_post_stats child_stats ON child_stats.post_id = children.id
              AND child_stats.hot_score_updated_at IS NOT NULL
              AND NOT (#{persisted_score_stale_sql("child_stats")})
            WHERE children.topic_id = path.topic_id
              AND children.reply_to_post_number = path.post_number
              AND children.post_number IS DISTINCT FROM path.path_child_post_number
              AND children.post_number > 1
              AND children.post_type IN (#{public_post_types.join(", ")})
          ) other_children ON TRUE
          ORDER BY path.depth ASC
        SQL
    end

    def self.persist_scores(scores)
      return if scores.empty?

      scores.each_slice(PERSIST_BATCH_SIZE) { |batch| persist_scores_batch(batch) }
    end

    def self.persist_scores_batch(scores)
      post_ids, hot_scores, thread_hot_scores = scores.transpose
      DB.exec(
        <<~SQL,
          INSERT INTO nested_view_post_stats (
            post_id,
            hot_score,
            thread_hot_score,
            hot_score_updated_at,
            created_at,
            updated_at
          )
          SELECT updates.post_id,
                 updates.hot_score,
                 updates.thread_hot_score,
                 clock_timestamp(),
                 NOW(),
                 NOW()
          FROM UNNEST(
            ARRAY[:post_ids]::bigint[],
            ARRAY[:hot_scores]::double precision[],
            ARRAY[:thread_hot_scores]::double precision[]
          ) AS updates(post_id, hot_score, thread_hot_score)
          ON CONFLICT (post_id) DO UPDATE SET
            hot_score = EXCLUDED.hot_score,
            thread_hot_score = EXCLUDED.thread_hot_score,
            hot_score_updated_at = EXCLUDED.hot_score_updated_at,
            updated_at = NOW()
        SQL
        post_ids: post_ids,
        hot_scores: hot_scores,
        thread_hot_scores: thread_hot_scores,
      )
    end
    private_class_method :persist_scores_batch

    def self.reset_topic_scores(topic_id)
      DB.exec(<<~SQL, topic_id: topic_id)
          WITH public_reply_counts AS (
            SELECT replies.reply_to_post_number AS post_number,
                   COUNT(*) AS reply_count
            FROM posts replies
            WHERE replies.topic_id = :topic_id
              AND replies.reply_to_post_number IS NOT NULL
              AND replies.post_number > 1
              AND #{public_post_sql("replies")}
            GROUP BY replies.reply_to_post_number
          ), scored AS (
            SELECT posts.id AS post_id,
                   #{hot_score_sql("posts", reply_count_sql: "public_reply_counts.reply_count")} AS hot_score
            FROM posts
            LEFT JOIN public_reply_counts ON public_reply_counts.post_number = posts.post_number
            WHERE posts.topic_id = :topic_id
              AND posts.post_number > 1
          )
          INSERT INTO nested_view_post_stats (
            post_id,
            hot_score,
            thread_hot_score,
            hot_score_updated_at,
            created_at,
            updated_at
          )
          SELECT scored.post_id,
                 scored.hot_score,
                 scored.hot_score,
                 clock_timestamp(),
                 NOW(),
                 NOW()
          FROM scored
          ON CONFLICT (post_id) DO UPDATE SET
            hot_score = EXCLUDED.hot_score,
            thread_hot_score = EXCLUDED.thread_hot_score,
            hot_score_updated_at = EXCLUDED.hot_score_updated_at,
            updated_at = NOW()
        SQL
    end

    def self.propagate_topic_scores(topic_id)
      rows = DB.query(<<~SQL, topic_id: topic_id)
            SELECT posts.id,
                   posts.post_number,
                   posts.reply_to_post_number,
                   stats.hot_score
            FROM posts
            INNER JOIN nested_view_post_stats stats ON stats.post_id = posts.id
            WHERE posts.topic_id = :topic_id
              AND posts.post_number > 1
              AND posts.post_type IN (#{public_post_types.join(", ")})
          SQL
      rows_by_number = rows.index_by { |row| row.post_number.to_i }
      child_counts = Hash.new(0)

      rows.each do |row|
        parent_number = row.reply_to_post_number&.to_i
        child_counts[parent_number] += 1 if rows_by_number.key?(parent_number)
      end

      thread_scores = rows.to_h { |row| [row.post_number.to_i, row.hot_score.to_f] }
      leaf_numbers = rows_by_number.keys.select { |post_number| child_counts[post_number].zero? }
      processed_count = 0
      leaf_index = 0

      # Propagate the hottest descendant from leaves to roots in one pass.
      while leaf_index < leaf_numbers.length
        post_number = leaf_numbers[leaf_index]
        leaf_index += 1
        processed_count += 1

        row = rows_by_number[post_number]
        parent_number = row.reply_to_post_number&.to_i
        next unless rows_by_number.key?(parent_number)

        thread_scores[parent_number] = [
          thread_scores[parent_number],
          thread_scores[post_number] - child_penalty,
        ].max
        child_counts[parent_number] -= 1
        leaf_numbers << parent_number if child_counts[parent_number].zero?
      end

      if processed_count != rows.length
        propagate_topic_scores_with_recursive_sql(topic_id)
        return
      end

      persist_scores(
        rows.map do |score_row|
          [
            score_row.id.to_i,
            score_row.hot_score.to_f,
            thread_scores.fetch(score_row.post_number.to_i),
          ]
        end,
      )
    end

    def self.propagate_topic_scores_with_recursive_sql(topic_id)
      DB.exec(<<~SQL, topic_id: topic_id, child_penalty: child_penalty)
          WITH RECURSIVE propagated AS (
            SELECT posts.id AS post_id,
                   posts.topic_id,
                   posts.post_number,
                   posts.reply_to_post_number,
                   stats.hot_score AS candidate_score,
                   ARRAY[posts.post_number]::integer[] AS path
            FROM posts
            JOIN nested_view_post_stats stats ON stats.post_id = posts.id
            WHERE posts.topic_id = :topic_id
              AND posts.post_number > 1
              AND posts.post_type IN (#{public_post_types.join(", ")})

            UNION ALL

            SELECT parent.id,
                   parent.topic_id,
                   parent.post_number,
                   parent.reply_to_post_number,
                   propagated.candidate_score - :child_penalty,
                   propagated.path || parent.post_number
            FROM propagated
            JOIN posts parent ON parent.topic_id = propagated.topic_id
              AND parent.post_number = propagated.reply_to_post_number
            WHERE parent.post_number > 1
              AND parent.post_type IN (#{public_post_types.join(", ")})
              AND NOT parent.post_number = ANY(propagated.path)
          ), thread_scores AS (
            SELECT post_id, MAX(candidate_score) AS thread_hot_score
            FROM propagated
            GROUP BY post_id
          )
          UPDATE nested_view_post_stats stats
          SET thread_hot_score = GREATEST(stats.hot_score, thread_scores.thread_hot_score),
              updated_at = NOW()
          FROM thread_scores
          WHERE stats.post_id = thread_scores.post_id
        SQL
    end
    private_class_method :propagate_topic_scores_with_recursive_sql

    def self.mark_topic_recalculated(topic_id)
      DB.exec(<<~SQL, topic_id: topic_id)
          INSERT INTO nested_view_post_stats (
            post_id,
            hot_score_updated_at,
            created_at,
            updated_at
          )
          SELECT posts.id, clock_timestamp(), NOW(), NOW()
          FROM posts
          WHERE posts.topic_id = :topic_id
            AND posts.post_number = 1
          ON CONFLICT (post_id) DO UPDATE SET
            hot_score_updated_at = EXCLUDED.hot_score_updated_at,
            updated_at = NOW()
        SQL
    end
  end
end
