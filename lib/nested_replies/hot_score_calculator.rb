# frozen_string_literal: true

module NestedReplies
  class HotScoreCalculator
    class InvalidTree < StandardError
    end

    class MissingOriginalPost < StandardError
    end

    HOT_SCORE_FLOOR = 0.0

    def self.formula_settings
      {
        like_weight: SiteSetting.nested_replies_hot_like_weight.to_f,
        reply_weight: SiteSetting.nested_replies_hot_reply_weight.to_f,
        freshness_max_bonus: SiteSetting.nested_replies_hot_freshness_max_bonus.to_f,
        freshness_half_life_seconds:
          SiteSetting.nested_replies_hot_freshness_half_life_hours.to_f.hours.to_f,
        child_penalty: SiteSetting.nested_replies_hot_child_penalty.to_f,
      }
    end

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

    def self.hot_score_sql(
      table_name,
      reply_count_sql: "0",
      now_sql: "CURRENT_TIMESTAMP",
      formula: formula_settings
    )
      engagement_sql =
        "COALESCE(#{table_name}.like_score, 0) * #{formula.fetch(:like_weight)} + " \
          "COALESCE(#{reply_count_sql}, 0) * #{formula.fetch(:reply_weight)}"
      age_seconds_sql = "GREATEST(EXTRACT(EPOCH FROM #{now_sql} - #{table_name}.created_at), 0)"
      freshness_sql =
        "#{formula.fetch(:freshness_max_bonus)} * " \
          "POWER(0.5, #{age_seconds_sql} / #{formula.fetch(:freshness_half_life_seconds)})"

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

      formula = formula_settings
      engagement =
        post.like_score.to_f * formula.fetch(:like_weight) +
          direct_reply_count.to_f * formula.fetch(:reply_weight)
      age_seconds = [now.to_f - post.created_at.to_f, 0.0].max
      freshness =
        formula.fetch(:freshness_max_bonus) *
          0.5**(age_seconds / formula.fetch(:freshness_half_life_seconds))
      Math.log(1 + [engagement, 0.0].max) + freshness
    end

    def self.public_post?(post)
      public_post_types.include?(post.post_type) && post.deleted_at.nil? && !post.hidden? &&
        !post.user_deleted?
    end

    def self.recalculate_topic(topic_id, timeout_ms: nil)
      return 0 if topic_id.blank?

      calculated_at = Time.current
      formula = formula_settings
      max_timeout_ms = SiteSetting.nested_replies_hot_max_statement_timeout_ms
      timeout_ms = (timeout_ms || max_timeout_ms).to_i.clamp(1, max_timeout_ms)
      result =
        ActiveRecord::Base.transaction do
          DB.exec "SET LOCAL statement_timeout = #{timeout_ms}"
          DB.exec(
            "SET LOCAL lock_timeout = #{[timeout_ms, SiteSetting.nested_replies_hot_lock_timeout_ms].min}",
          )
          DB.query(refresh_sql, topic_id: topic_id, calculated_at: calculated_at, **formula).first
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
              formula: {
                like_weight: ":like_weight",
                reply_weight: ":reply_weight",
                freshness_max_bonus: ":freshness_max_bonus",
                freshness_half_life_seconds: ":freshness_half_life_seconds",
              },
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
                     propagation.propagated_score - :child_penalty,
                     propagation.path || parent.post_number
              FROM propagation
              JOIN posts parent
                ON parent.topic_id = :topic_id
               AND parent.post_number = propagation.parent_post_number
              WHERE propagation.parent_post_number > 1
                AND (#{carrier_parent_post_sql})
                AND propagation.propagated_score > :child_penalty
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
                calculated_at
              )
              SELECT :topic_id,
                     :calculated_at::timestamp
              FROM tree_validation
              WHERE tree_validation.valid
                AND EXISTS (SELECT 1 FROM original_post)
              ON CONFLICT (topic_id) DO UPDATE SET
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
