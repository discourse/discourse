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
        "COALESCE(nested_view_post_stats.thread_hot_score, 0) DESC, " \
          "COALESCE(nested_view_post_stats.hot_score, 0) DESC, " \
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

    def self.hot_score_join_sql
      "LEFT JOIN nested_view_post_stats ON nested_view_post_stats.post_id = posts.id"
    end

    def self.sort_in_memory(posts, algorithm, hot_scores: nil)
      raise ArgumentError, "Invalid sort algorithm: #{algorithm}" unless valid?(algorithm)

      case algorithm
      when "top"
        posts.sort_by { |post| [-post.like_count, post.post_number] }
      when "hot"
        hot_scores ||= {}
        posts.sort_by do |post|
          thread_hot_score, hot_score = hot_score_values(post, hot_scores[post.id])
          [-thread_hot_score, -hot_score, post.post_number]
        end
      when "new"
        posts.sort_by { |post| -post.created_at.to_i }
      when "old"
        posts.sort_by(&:post_number)
      end
    end

    def self.hot_score_values(post, scores)
      case scores
      when Array
        hot_score = (scores[1] || scores[0] || 0.0).to_f
        thread_hot_score = (scores[0] || hot_score).to_f
        relative_hot_score = (scores[3] || scores[2] || 0.0).to_f
        relative_thread_hot_score = (scores[2] || relative_hot_score).to_f
        [thread_hot_score, hot_score, relative_thread_hot_score, relative_hot_score]
      when Hash
        hot_score = (scores[:hot_score] || scores["hot_score"] || 0.0).to_f
        thread_hot_score =
          (scores[:thread_hot_score] || scores["thread_hot_score"] || hot_score).to_f
        relative_hot_score =
          (scores[:relative_hot_score] || scores["relative_hot_score"] || 0.0).to_f
        relative_thread_hot_score =
          (
            scores[:relative_thread_hot_score] || scores["relative_thread_hot_score"] ||
              relative_hot_score
          ).to_f
        [thread_hot_score, hot_score, relative_thread_hot_score, relative_hot_score]
      else
        hot_score = (scores || post.try(:nested_hot_score) || 0.0).to_f
        thread_hot_score = (post.try(:nested_thread_hot_score) || hot_score).to_f
        relative_hot_score = (post.try(:nested_relative_hot_score) || 0.0).to_f
        relative_thread_hot_score =
          (post.try(:nested_relative_thread_hot_score) || relative_hot_score).to_f
        [thread_hot_score, hot_score, relative_thread_hot_score, relative_hot_score]
      end
    end

    def self.valid?(algorithm)
      ALGORITHMS.include?(algorithm)
    end
  end
end
