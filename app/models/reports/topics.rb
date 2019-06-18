# frozen_string_literal: true

Report.add_report('topics') do |report|
  category_filter = report.filters.dig(:category)
  report.add_filter('category', default: category_filter)

  basic_report_about report, Topic, :listable_count_per_day, report.start_date, report.end_date, category_filter

  countable = Topic.listable_topics
  if category_filter
    countable = countable.in_category_and_subcategories(category_filter)
  end
  add_counts report, countable, 'topics.created_at'
end
