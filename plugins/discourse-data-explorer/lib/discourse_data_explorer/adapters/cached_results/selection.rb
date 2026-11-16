# frozen_string_literal: true

module DiscourseDataExplorer
  module Adapters
    class CachedResults
      class Selection < Data.define(:queries, :params)
        def with_params(value) = with(params: value)

        def within(scope) = with(queries: queries & scope.queries)

        def include?(query) = queries.include?(query)

        def cached_results(user)
          queries.filter_map { QueryRunner.cached_entry(it, params, current_user: user) }
        end
      end
    end
  end
end
