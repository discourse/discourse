# frozen_string_literal: true

module NestedReplies
  module Sort
    ALGORITHMS = %w[top new old].freeze

    def self.sql_order_expression(algorithm)
      raise ArgumentError, "Invalid sort algorithm: #{algorithm}" unless valid?(algorithm)

      case algorithm
      when "top"
        "like_count DESC, post_number ASC"
      when "new"
        "created_at DESC"
      when "old"
        "post_number ASC"
      end
    end

    def self.apply(scope, algorithm)
      scope.order(Arel.sql(sql_order_expression(algorithm)))
    end

    def self.sort_in_memory(posts, algorithm)
      case algorithm
      when "top"
        posts.sort_by { |p| [-p.like_count, p.post_number] }
      when "new"
        posts.sort_by { |p| -p.created_at.to_i }
      when "old"
        posts.sort_by(&:post_number)
      else
        posts.sort_by { |p| [-p.like_count, p.post_number] }
      end
    end

    def self.valid?(algorithm)
      ALGORITHMS.include?(algorithm)
    end
  end
end
