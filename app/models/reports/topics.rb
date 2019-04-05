Report.add_report("topics") do |report|
  report.category_filtering = true
  basic_report_about report, Topic, :listable_count_per_day, report.start_date, report.end_date, report.category_id
  countable = Topic.listable_topics
  countable = countable.in_category_and_subcategories(report.category_id) if report.category_id
  add_counts report, countable, 'topics.created_at'
end
