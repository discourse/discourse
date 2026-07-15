# frozen_string_literal: true

module NestedReplies
  class HotScoreCalculator
    class InvalidTree < StandardError
    end

    class MissingOriginalPost < StandardError
    end

    FORMULA_VERSION = 1
    HOT_SCORE_FLOOR = 0.0
    LIKE_WEIGHT = 1.0
    REPLY_WEIGHT = 2.0
    FRESHNESS_MAX_BONUS = 3.0
    FRESHNESS_HALF_LIFE_SECONDS = 7.days.to_f
    CHILD_PENALTY = 0.25
    MAX_STATEMENT_TIMEOUT_MS = 10_000
    LOCK_TIMEOUT_MS = 1_000

    def self.public_post_types
      [Post.types[:regular], Post.types[:moderator_action]]
    end

    def self.carrier_post_sql(table_name)
      "#{table_name}.post_type IN (#{public_post_types.join(", ")})"
    end

    def self.public_post_sql(table_name)
      <<~SQL.squish
        #{carrier_post_sql(table_name)}
        AND #{table_name}.deleted_at IS NULL
        AND NOT #{table_name}.hidden
        AND NOT #{table_name}.user_deleted
      SQL
    end

    def self.hot_score_sql(table_name, reply_count_sql: "0", now_sql: "CURRENT_TIMESTAMP")
      engagement_sql =
        "COALESCE(#{table_name}.like_score, 0) * #{LIKE_WEIGHT} + " \
          "COALESCE(#{reply_count_sql}, 0) * #{REPLY_WEIGHT}"
      age_seconds_sql = "GREATEST(EXTRACT(EPOCH FROM #{now_sql} - #{table_name}.created_at), 0)"
      freshness_sql =
        "#{FRESHNESS_MAX_BONUS} * " \
          "POWER(0.5, #{age_seconds_sql} / #{FRESHNESS_HALF_LIFE_SECONDS})"

      <<~SQL.squish
        CASE
          WHEN #{public_post_sql(table_name)}
          THEN LN(1 + GREATEST(#{engagement_sql}, 0)) + #{freshness_sql}
          ELSE #{HOT_SCORE_FLOOR}
        END
      SQL
    end

    def self.score_for(post, direct_reply_count: 0, now: Time.current)
      return HOT_SCORE_FLOOR unless public_post?(post)

      engagement = post.like_score.to_f * LIKE_WEIGHT + direct_reply_count.to_f * REPLY_WEIGHT
      age_seconds = [now.to_f - post.created_at.to_f, 0.0].max
      freshness = FRESHNESS_MAX_BONUS * 0.5**(age_seconds / FRESHNESS_HALF_LIFE_SECONDS)
      Math.log(1 + [engagement, 0.0].max) + freshness
    end

    def self.public_post?(post)
      public_post_types.include?(post.post_type) && post.deleted_at.nil? && !post.hidden? &&
        !post.user_deleted?
    end

    def self.recalculate_topic(topic_id, timeout_ms: MAX_STATEMENT_TIMEOUT_MS)
      return 0 if topic_id.blank?

      calculated_at = Time.current
      timeout_ms = timeout_ms.to_i.clamp(1, MAX_STATEMENT_TIMEOUT_MS)
      result =
        ActiveRecord::Base.transaction do
          DB.exec "SET LOCAL statement_timeout = #{timeout_ms}"
          DB.exec "SET LOCAL lock_timeout = #{[timeout_ms, LOCK_TIMEOUT_MS].min}"
          DB.query(refresh_sql, topic_id: topic_id, calculated_at: calculated_at).first
        end

      raise InvalidTree, "Cycle in nested replies for topic #{topic_id}" if result.invalid_tree
      unless result.snapshot_written
        raise MissingOriginalPost, "Missing original post for topic #{topic_id}"
      end

      result.rows_written.to_i
    end

    def self.refresh_sql
      @refresh_sql ||=
        begin
          own_score_sql =
            hot_score_sql(
              "topic_posts",
              reply_count_sql: "direct_reply_counts.direct_reply_count",
              now_sql: ":calculated_at::timestamp",
            )
          public_topic_post_sql = public_post_sql("posts")
          carrier_topic_post_sql = carrier_post_sql("posts")
          carrier_parent_post_sql = carrier_post_sql("parent")

          <<~SQL
            WITH RECURSIVE
            topic_posts AS MATERIALIZED (
              SELECT posts.id,
                     posts.post_number,
                     posts.reply_to_post_number,
                     posts.post_type,
                     posts.deleted_at,
                     posts.hidden,
                     posts.user_deleted,
                     posts.like_score,
                     posts.created_at,
                     (#{public_topic_post_sql}) AS is_public,
                     (#{carrier_topic_post_sql}) AS is_carrier
              FROM posts
              WHERE posts.topic_id = :topic_id
            ),
            direct_reply_counts AS (
              SELECT child.reply_to_post_number,
                     COUNT(*) FILTER (WHERE child.is_public) AS direct_reply_count
              FROM topic_posts child
              WHERE child.post_number > 1
                AND child.reply_to_post_number IS NOT NULL
              GROUP BY child.reply_to_post_number
            ),
            scored_posts AS MATERIALIZED (
              SELECT topic_posts.id,
                     topic_posts.post_number,
                     topic_posts.reply_to_post_number,
                     topic_posts.is_public,
                     topic_posts.is_carrier,
                     CASE
                       WHEN topic_posts.post_number = 1 THEN NULL
                       ELSE #{own_score_sql}
                     END AS hot_score
              FROM topic_posts
              LEFT JOIN direct_reply_counts
                ON direct_reply_counts.reply_to_post_number = topic_posts.post_number
            ),
            cycle_candidates AS (
              SELECT topic_posts.post_number,
                     topic_posts.reply_to_post_number
              FROM topic_posts
              WHERE topic_posts.post_number > 1
                AND topic_posts.reply_to_post_number >= topic_posts.post_number
            ),
            cycle_walk (
              current_post_number,
              parent_post_number,
              path,
              cycle
            ) AS (
              SELECT cycle_candidates.post_number,
                     cycle_candidates.reply_to_post_number,
                     ARRAY[cycle_candidates.post_number]::integer[],
                     false
              FROM cycle_candidates

              UNION ALL

              SELECT parent.post_number,
                     parent.reply_to_post_number,
                     cycle_walk.path || parent.post_number,
                     parent.post_number = ANY(cycle_walk.path)
              FROM cycle_walk
              JOIN LATERAL (
                SELECT posts.post_number,
                       posts.reply_to_post_number
                FROM posts
                WHERE posts.topic_id = :topic_id
                  AND posts.post_number = cycle_walk.parent_post_number
                LIMIT 1
              ) parent ON true
              WHERE cycle_walk.parent_post_number > 1
                AND NOT cycle_walk.cycle
            ),
            tree_validation AS MATERIALIZED (
              SELECT NOT EXISTS (
                SELECT 1
                FROM cycle_walk
                WHERE cycle_walk.cycle
              ) AS valid
            ),
            original_post AS MATERIALIZED (
              SELECT topic_posts.id
              FROM topic_posts
              WHERE topic_posts.post_number = 1
              LIMIT 1
            ),
            propagation (
              target_post_id,
              parent_post_number,
              propagated_score,
              path
            ) AS (
              SELECT scored_posts.id,
                     scored_posts.reply_to_post_number,
                     scored_posts.hot_score,
                     ARRAY[scored_posts.post_number]::integer[]
              FROM scored_posts
              CROSS JOIN tree_validation
              WHERE scored_posts.post_number > 1
                AND scored_posts.is_public
                AND tree_validation.valid

              UNION ALL

              SELECT parent.id,
                     parent.reply_to_post_number,
                     propagation.propagated_score - #{CHILD_PENALTY},
                     propagation.path || parent.post_number
              FROM propagation
              JOIN posts parent
                ON parent.topic_id = :topic_id
               AND parent.post_number = propagation.parent_post_number
              WHERE propagation.parent_post_number > 1
                AND (#{carrier_parent_post_sql})
                AND propagation.propagated_score > #{CHILD_PENALTY}
                AND NOT parent.post_number = ANY(propagation.path)
            ),
            thread_scores AS (
              SELECT propagation.target_post_id AS post_id,
                     MAX(propagation.propagated_score) AS thread_hot_score
              FROM propagation
              GROUP BY propagation.target_post_id
            ),
            calculated_scores AS MATERIALIZED (
              SELECT scored_posts.id AS post_id,
                     scored_posts.hot_score,
                     GREATEST(
                       scored_posts.hot_score,
                       COALESCE(thread_scores.thread_hot_score, #{HOT_SCORE_FLOOR})
                     ) AS thread_hot_score
              FROM scored_posts
              LEFT JOIN thread_scores ON thread_scores.post_id = scored_posts.id
              WHERE scored_posts.post_number > 1
                AND scored_posts.is_carrier
            ),
            upserted_scores AS (
              INSERT INTO nested_hot_post_scores (
                post_id,
                topic_id,
                hot_score,
                thread_hot_score
              )
              SELECT calculated_scores.post_id,
                     :topic_id,
                     calculated_scores.hot_score,
                     calculated_scores.thread_hot_score
              FROM calculated_scores
              CROSS JOIN tree_validation
              WHERE tree_validation.valid
                AND EXISTS (SELECT 1 FROM original_post)
              ON CONFLICT (post_id) DO UPDATE SET
                topic_id = EXCLUDED.topic_id,
                hot_score = EXCLUDED.hot_score,
                thread_hot_score = EXCLUDED.thread_hot_score
              RETURNING post_id
            ),
            removed_scores AS (
              DELETE FROM nested_hot_post_scores cached_scores
              WHERE cached_scores.topic_id = :topic_id
                AND (SELECT valid FROM tree_validation)
                AND EXISTS (SELECT 1 FROM original_post)
                AND NOT EXISTS (
                  SELECT 1
                  FROM calculated_scores
                  WHERE calculated_scores.post_id = cached_scores.post_id
                )
              RETURNING post_id
            ),
            upserted_snapshot AS (
              INSERT INTO nested_hot_score_snapshots (
                topic_id,
                formula_version,
                calculated_at
              )
              SELECT :topic_id,
                     #{FORMULA_VERSION},
                     :calculated_at::timestamp
              FROM tree_validation
              WHERE tree_validation.valid
                AND EXISTS (SELECT 1 FROM original_post)
              ON CONFLICT (topic_id) DO UPDATE SET
                formula_version = EXCLUDED.formula_version,
                calculated_at = EXCLUDED.calculated_at
              RETURNING topic_id
            )
            SELECT (SELECT COUNT(*) FROM upserted_scores) AS rows_written,
                   (SELECT COUNT(*) FROM removed_scores) AS rows_removed,
                   NOT tree_validation.valid AS invalid_tree,
                   EXISTS (SELECT 1 FROM upserted_snapshot) AS snapshot_written
            FROM tree_validation
          SQL
        end
    end
    private_class_method :refresh_sql
  end
end
