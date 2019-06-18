# frozen_string_literal: true

Report.add_report('topics_with_no_response') do |report|
  category_filter = report.filters.dig(:category)
  report.add_filter('category', default: category_filter)

  report.data = []
  Topic.with_no_response_per_day(report.start_date, report.end_date, category_filter).each do |r|
    report.data << { x: r['date'], y: r['count'].to_i }
  end

  report.total = Topic.with_no_response_total(category_id: category_filter)

  report.prev30Days = Topic.with_no_response_total(start_date: report.start_date - 30.days, end_date: report.start_date, category_id: category_filter)
end
