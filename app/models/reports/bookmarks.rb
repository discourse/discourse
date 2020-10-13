# frozen_string_literal: true

Report.add_report('bookmarks') do |report|
  report.icon = 'bookmark'

  category_filter = report.filters.dig(:category)
  report.add_filter('category', default: category_filter)

  report.data = []
  Bookmark.count_per_day(
    category_id: category_filter,
    start_date: report.start_date,
    end_date: report.end_date
  ).each do |date, count|
    report.data << { x: date, y: count }
  end
  add_counts report, Bookmark, 'bookmarks.created_at'
end
