# frozen_string_literal: true

module NestedReplies
  class HotScoreCalculator
    ROOT_POST_NUMBER = 1
    RELATIVE_HOT_SCORE_BASELINE = 1.0

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
      ENGAGEMENT_WEIGHTS
        .map { |column, weight| "COALESCE(#{table_name}.#{column}, 0) * #{weight}" }
        .join(" + ")
    end

    def self.hot_score_sql(table_name, time_scale_sql)
      "LN(1 + GREATEST(#{engagement_score_sql(table_name)}, 0)) + " \
        "EXTRACT(EPOCH FROM #{table_name}.created_at) / #{time_scale_sql}"
    end

    def self.relative_hot_score_min_spread
      SiteSetting.nested_replies_relative_hot_score_min_spread.to_f
    end

    def self.relative_hot_score_floor
      SiteSetting.nested_replies_relative_hot_score_floor.to_f
    end

    def self.hot_score_child_decay
      SiteSetting.nested_replies_hot_score_child_decay.to_f
    end

    def self.relative_hot_score_sql(score_sql:, median_sql:, spread_sql:)
      min_spread = relative_hot_score_min_spread
      floor = relative_hot_score_floor
      spread = "GREATEST(COALESCE(NULLIF(#{spread_sql}, 0), #{min_spread}), #{min_spread})"

      "GREATEST(#{floor}, #{RELATIVE_HOT_SCORE_BASELINE} + ((#{score_sql}) - (#{median_sql})) / #{spread})"
    end

    def self.time_scale_seconds(sibling_count)
      count = sibling_count.to_i
      BUCKETS.find { |max_count, _| count <= max_count }.second.to_i
    end

    def self.root_sibling_group?(reply_to_post_number)
      reply_to_post_number.nil? || reply_to_post_number == ROOT_POST_NUMBER
    end

    def self.sibling_group_where_sql(table_name, reply_to_post_number)
      if root_sibling_group?(reply_to_post_number)
        "(#{table_name}.reply_to_post_number IS NULL OR #{table_name}.reply_to_post_number = #{ROOT_POST_NUMBER})"
      else
        "#{table_name}.reply_to_post_number IS NOT DISTINCT FROM :reply_to_post_number"
      end
    end

    def self.recalculate_for_post_if_nested(post_id)
      post = Post.where(id: post_id).where("post_number > 1").first
      return if post.blank? || !post.topic&.nested_view?

      recalculate_for_post(post.id)
    end

    def self.recalculate_for_post(post_id)
      topic_id, reply_to_post_number =
        Post
          .with_deleted
          .where(id: post_id)
          .where("post_number > 1")
          .pick(:topic_id, :reply_to_post_number)
      return if topic_id.blank?

      recalculate_for_sibling_group(topic_id: topic_id, reply_to_post_number: reply_to_post_number)
    end

    def self.recalculate_siblings_for_post(post)
      return if post.blank?

      recalculate_for_sibling_group(
        topic_id: post.topic_id,
        reply_to_post_number: post.reply_to_post_number,
      )
    end

    def self.recalculate_parents_for_post_numbers(topic_id:, post_numbers:)
      post_numbers = Array(post_numbers).compact.uniq
      return if post_numbers.empty?

      Post
        .with_deleted
        .where(topic_id: topic_id, post_number: post_numbers)
        .where("post_number > 1")
        .pluck(:id)
        .each { |post_id| recalculate_for_post(post_id) }
    end

    def self.recalculate_for_sibling_group(topic_id:, reply_to_post_number:)
      sibling_count_where_sql = sibling_group_where_sql("posts", reply_to_post_number)
      recalculation_where_sql = sibling_group_where_sql("p", reply_to_post_number)
      sibling_count_scope = Post.with_deleted.where(topic_id: topic_id).where("post_number > 1")
      sibling_count_scope =
        if root_sibling_group?(reply_to_post_number)
          sibling_count_scope.where(sibling_count_where_sql)
        else
          sibling_count_scope.where(
            sibling_count_where_sql,
            reply_to_post_number: reply_to_post_number,
          )
        end
      post_numbers = sibling_count_scope.pluck(:post_number)
      return if post_numbers.empty?

      time_scale_seconds = time_scale_seconds(post_numbers.size)

      sql_params = { topic_id: topic_id, time_scale_seconds: time_scale_seconds }
      unless root_sibling_group?(reply_to_post_number)
        sql_params[:reply_to_post_number] = reply_to_post_number
      end

      relative_score_sql =
        relative_hot_score_sql(
          score_sql: "scored.hot_score",
          median_sql: "distribution.median_hot_score",
          spread_sql: "distribution.hot_score_spread",
        )

      DB.exec(<<~SQL, **sql_params)
        WITH scored AS (
          SELECT p.id,
                 #{hot_score_sql("p", ":time_scale_seconds")} AS hot_score,
                 p.topic_id,
                 p.reply_to_post_number,
                 p.post_number
          FROM posts p
          WHERE p.topic_id = :topic_id
            AND #{recalculation_where_sql}
            AND p.post_number > 1
        ), distribution AS (
          SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY scored.hot_score) AS median_hot_score,
                 COALESCE(STDDEV_POP(scored.hot_score), 0) AS hot_score_spread
          FROM scored
        ), relative_scored AS (
          SELECT scored.*,
                 #{relative_score_sql} AS relative_hot_score
          FROM scored
          CROSS JOIN distribution
        )
        INSERT INTO nested_view_post_stats (
          post_id,
          hot_score,
          thread_hot_score,
          relative_hot_score,
          relative_thread_hot_score,
          hot_score_updated_at,
          topic_id,
          reply_to_post_number,
          post_number,
          created_at,
          updated_at
        )
        SELECT relative_scored.id,
               relative_scored.hot_score,
               relative_scored.hot_score,
               relative_scored.relative_hot_score,
               relative_scored.relative_hot_score,
               NOW(),
               relative_scored.topic_id,
               relative_scored.reply_to_post_number,
               relative_scored.post_number,
               NOW(),
               NOW()
        FROM relative_scored
        ON CONFLICT (post_id) DO UPDATE SET
          hot_score = EXCLUDED.hot_score,
          thread_hot_score = EXCLUDED.thread_hot_score,
          relative_hot_score = EXCLUDED.relative_hot_score,
          relative_thread_hot_score = EXCLUDED.relative_thread_hot_score,
          hot_score_updated_at = EXCLUDED.hot_score_updated_at,
          topic_id = EXCLUDED.topic_id,
          reply_to_post_number = EXCLUDED.reply_to_post_number,
          post_number = EXCLUDED.post_number,
          updated_at = NOW()
      SQL

      recalculate_thread_hot_scores_for_post_numbers(topic_id: topic_id, post_numbers: post_numbers)
    end

    def self.recalculate_thread_hot_scores_for_post_numbers(topic_id:, post_numbers:)
      post_numbers = Array(post_numbers).compact.uniq
      return if post_numbers.empty?

      affected_posts = DB.query(<<~SQL, topic_id: topic_id, post_numbers: post_numbers)
        WITH RECURSIVE affected AS (
          SELECT p.id AS post_id,
                 p.topic_id,
                 p.post_number,
                 p.reply_to_post_number,
                 0 AS depth,
                 ARRAY[p.post_number]::integer[] AS path
          FROM posts p
          WHERE p.topic_id = :topic_id
            AND p.post_number = ANY(ARRAY[:post_numbers]::integer[])
            AND p.post_number > 1
          UNION ALL
          SELECT parent.id AS post_id,
                 parent.topic_id,
                 parent.post_number,
                 parent.reply_to_post_number,
                 affected.depth + 1 AS depth,
                 affected.path || parent.post_number
          FROM affected
          JOIN posts parent ON parent.topic_id = affected.topic_id
            AND parent.post_number = affected.reply_to_post_number
          WHERE parent.post_number > 1
            AND NOT parent.post_number = ANY(affected.path)
        )
        SELECT post_id, MAX(depth) AS depth
        FROM affected
        GROUP BY post_id
        ORDER BY depth ASC
      SQL

      affected_posts
        .group_by { |post| post.depth.to_i }
        .sort_by { |depth, _| depth }
        .each { |_, posts| recalculate_thread_hot_scores_for_posts(posts.map(&:post_id)) }
    end

    def self.recalculate_thread_hot_scores_for_posts(post_ids)
      post_ids = Array(post_ids).compact.uniq
      return if post_ids.empty?

      DB.exec(<<~SQL, post_ids: post_ids, child_decay: hot_score_child_decay)
          UPDATE nested_view_post_stats stats
          SET thread_hot_score = child_scores.thread_hot_score,
              relative_thread_hot_score = child_scores.relative_thread_hot_score,
              updated_at = NOW()
          FROM (
            SELECT parent_stats.post_id,
                   GREATEST(
                     COALESCE(parent_stats.hot_score, 0),
                     COALESCE(MAX(child_stats.thread_hot_score), 0) * :child_decay
                   ) AS thread_hot_score,
                   GREATEST(
                     COALESCE(parent_stats.relative_hot_score, 0),
                     COALESCE(MAX(child_stats.relative_thread_hot_score), 0) * :child_decay
                   ) AS relative_thread_hot_score
            FROM posts parent_posts
            JOIN nested_view_post_stats parent_stats ON parent_stats.post_id = parent_posts.id
            LEFT JOIN posts child_posts ON child_posts.topic_id = parent_posts.topic_id
              AND child_posts.reply_to_post_number = parent_posts.post_number
              AND child_posts.post_number > 1
            LEFT JOIN nested_view_post_stats child_stats ON child_stats.post_id = child_posts.id
            WHERE parent_posts.id = ANY(ARRAY[:post_ids]::integer[])
            GROUP BY parent_stats.post_id, parent_stats.hot_score, parent_stats.relative_hot_score
          ) child_scores
          WHERE stats.post_id = child_scores.post_id
        SQL
    end
  end
end
