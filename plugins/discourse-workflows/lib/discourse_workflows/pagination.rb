# frozen_string_literal: true

module DiscourseWorkflows
  module Pagination
    DEFAULT_LIMIT = 25
    MAX_LIMIT = 100

    Page = Data.define(:records, :total_rows, :load_more_url)

    def self.normalize_limit(limit)
      (limit || DEFAULT_LIMIT).clamp(1, MAX_LIMIT)
    end

    def self.cursor_page(scope:, cursor:, limit:, path:, query: {}, column: :id)
      paginated_scope = cursor ? scope.where("#{column} < ?", cursor) : scope
      records = paginated_scope.limit(limit + 1).to_a
      has_more = records.size > limit
      records = records.first(limit) if has_more

      Page.new(
        records: records,
        total_rows: scope.count,
        load_more_url: build_load_more_url(path, records, limit, query, has_more, column),
      )
    end

    def self.build_load_more_url(path, records, limit, query, has_more, column = :id)
      return if !has_more || records.empty?

      cursor = records.last.public_send(column)
      "#{path}?#{query.merge(cursor: cursor, limit: limit).compact_blank.to_query}"
    end
  end
end
