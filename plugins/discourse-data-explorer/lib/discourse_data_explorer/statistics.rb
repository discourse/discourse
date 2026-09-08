# frozen_string_literal: true

module DiscourseDataExplorer
  module Statistics
    extend PeriodCountHelper

    class << self
      def queries_total
        { count: Query.user_queries.count }
      end

      def queries_created
        period_counts(Query.user_queries, :created_at, count: false)
      end

      def queries_edited
        period_counts(
          Query.user_queries.where("updated_at > created_at"),
          :updated_at,
          count: false,
        )
      end

      def queries_executed
        period_counts(QueryStat.for_user_queries, :date, count: false) do |scope|
          scope.distinct.count(:query_id)
        end
      end

      def executions
        period_counts(QueryStat.for_user_queries, :date) { |scope| scope.sum(:total_runs) }
      end
    end
  end
end
