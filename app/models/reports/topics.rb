# frozen_string_literal: true

Report.add_report('topics') do |report|
  category_id, include_subcategories = report.add_category_filter

  basic_report_about report, Topic, :listable_count_per_day, report.start_date, report.end_date, category_id, include_subcategories

  countable = Topic.listable_topics
  countable = countable.where(category_id: include_subcategories ? Category.subcategory_ids(category_id) : category_id) if category_id

  add_counts report, countable, 'topics.created_at'
end
