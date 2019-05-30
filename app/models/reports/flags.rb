# frozen_string_literal: true

Report.add_report('flags') do |report|
  category_filter = report.filters.dig(:category)
  report.add_filter('category', default: category_filter)

  report.icon = 'flag'
  report.higher_is_better = false

  basic_report_about(
    report,
    ReviewableFlaggedPost,
    :count_by_date,
    report.start_date,
    report.end_date,
    category_filter
  )

  countable = ReviewableFlaggedPost.scores_with_topics

  if category_filter
    countable.merge!(Topic.in_category_and_subcategories(category_filter))
  end

  add_counts report, countable, 'reviewable_scores.created_at'
end
