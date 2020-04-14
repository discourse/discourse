# frozen_string_literal: true

Report.add_report('topics') do |report|
  category_id, include_subcategories = report.add_category_filter

  basic_report_about report, Topic, :listable_count_per_day, report.start_date, report.end_date, category_id, include_subcategories

  countable = Topic.listable_topics

  if category_id
    if include_subcategories
      countable = countable.in_category_and_subcategories(category_id)
    else
      countable = countable.where(category_id: category_id)
    end
  end

  add_counts report, countable, 'topics.created_at'
end
