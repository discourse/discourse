# frozen_string_literal: true

module Reports::Bookmarks
  extend ActiveSupport::Concern

  class_methods do
    def report_bookmarks(report)
      report.icon = "bookmark"

      category_filter = report.filters.dig(:category)
      report.add_filter("category", type: "category", default: category_filter)

      report.data = []
      Bookmark
        .count_per_day(
          category_id: category_filter,
          start_date: report.start_date,
          end_date: report.end_date,
        )
        .each { |date, count| report.data << { x: date, y: count } }
      add_counts report, Bookmark, "bookmarks.created_at"
    end
  end
end
