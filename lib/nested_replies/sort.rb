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
        "#{hot_score_expression(posts_table, :thread_hot_score)} DESC, " \
          "#{hot_score_expression(posts_table, :hot_score)} DESC, " \
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
        LEFT JOIN nested_hot_post_scores
          ON nested_hot_post_scores.post_id = #{posts_table}.id
      SQL
    end

    def self.hot_score_expression(posts_table, column)
      fallback = HotScoreCalculator.hot_score_sql(posts_table)
      "COALESCE(nested_hot_post_scores.#{column}, #{fallback})"
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
      if scores.present?
        thread_hot_score, hot_score = scores
        hot_score = (hot_score || thread_hot_score || 0.0).to_f
        thread_hot_score = (thread_hot_score || hot_score).to_f
        [thread_hot_score, hot_score]
      else
        hot_score = HotScoreCalculator.score_for(post).to_f
        [hot_score, hot_score]
      end
    end

    def self.valid?(algorithm)
      ALGORITHMS.include?(algorithm)
    end
  end
end
