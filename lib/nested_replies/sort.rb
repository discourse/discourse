# frozen_string_literal: true

module NestedReplies
  module Sort
    ALGORITHMS = %w[top hot new old].freeze

    def self.sql_order_expression(algorithm, posts_table: "posts")
      raise ArgumentError, "Invalid sort algorithm: #{algorithm}" unless valid?(algorithm)

      case algorithm
      when "top"
        "#{posts_table}.like_count DESC, #{posts_table}.post_number ASC"
      when "hot"
        fallback_score = NestedReplies::HotScoreCalculator.fallback_hot_score_sql(posts_table)
        stale_score =
          NestedReplies::HotScoreCalculator.persisted_score_stale_sql(
            topic_stats_table: "nested_hot_topic_stats",
          )
        "CASE WHEN #{stale_score} " \
          "THEN #{fallback_score} ELSE nested_view_post_stats.thread_hot_score END DESC, " \
          "CASE WHEN #{stale_score} " \
          "THEN #{fallback_score} ELSE nested_view_post_stats.hot_score END DESC, " \
          "#{posts_table}.post_number ASC"
      when "new"
        "#{posts_table}.created_at DESC"
      when "old"
        "#{posts_table}.post_number ASC"
      end
    end

    def self.apply(scope, algorithm)
      scope = scope.joins(hot_score_join_sql) if algorithm == "hot"
      scope.order(Arel.sql(sql_order_expression(algorithm)))
    end

    def self.hot_score_join_sql(posts_table: "posts")
      <<~SQL.squish
        LEFT JOIN nested_view_post_stats
          ON nested_view_post_stats.post_id = #{posts_table}.id
        LEFT JOIN posts nested_hot_original_post
          ON nested_hot_original_post.topic_id = #{posts_table}.topic_id
         AND nested_hot_original_post.post_number = 1
        LEFT JOIN nested_view_post_stats nested_hot_topic_stats
          ON nested_hot_topic_stats.post_id = nested_hot_original_post.id
      SQL
    end

    def self.sort_in_memory(posts, algorithm, hot_scores: nil, direct_reply_counts: nil)
      raise ArgumentError, "Invalid sort algorithm: #{algorithm}" unless valid?(algorithm)

      case algorithm
      when "top"
        posts.sort_by { |post| [-post.like_count, post.post_number] }
      when "hot"
        hot_scores ||= {}
        direct_reply_counts ||= {}
        posts.sort_by do |post|
          thread_hot_score, hot_score =
            hot_score_values(
              post,
              hot_scores[post.id],
              direct_reply_count: direct_reply_counts[post.post_number],
            )
          [-thread_hot_score, -hot_score, post.post_number]
        end
      when "new"
        posts.sort_by { |post| -post.created_at.to_i }
      when "old"
        posts.sort_by(&:post_number)
      end
    end

    def self.hot_score_values(post, scores, direct_reply_count: nil)
      case scores
      when Array
        hot_score = (scores[1] || scores[0] || 0.0).to_f
        thread_hot_score = (scores[0] || hot_score).to_f
        [thread_hot_score, hot_score]
      when Hash
        hot_score = (scores[:hot_score] || scores["hot_score"] || 0.0).to_f
        thread_hot_score =
          (scores[:thread_hot_score] || scores["thread_hot_score"] || hot_score).to_f
        [thread_hot_score, hot_score]
      else
        hot_score =
          (
            scores ||
              HotScoreCalculator.score_for(post, direct_reply_count: direct_reply_count.to_i)
          ).to_f
        [hot_score, hot_score]
      end
    end

    def self.valid?(algorithm)
      ALGORITHMS.include?(algorithm)
    end
  end
end
