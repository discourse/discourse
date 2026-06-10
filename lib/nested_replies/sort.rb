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
        "COALESCE(nested_view_post_stats.hot_score, 0) DESC, #{posts_table}.post_number ASC"
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
        posts.sort_by { |p| [-p.like_count, p.post_number] }
      when "hot"
        hot_scores ||= {}
        posts.sort_by do |p|
          [-(hot_scores[p.id] || p.try(:nested_hot_score) || 0.0).to_f, p.post_number]
        end
      when "new"
        posts.sort_by { |p| -p.created_at.to_i }
      when "old"
        posts.sort_by(&:post_number)
      end
    end

    def self.valid?(algorithm)
      ALGORITHMS.include?(algorithm)
    end
  end
end
