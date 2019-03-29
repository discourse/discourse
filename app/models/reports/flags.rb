Report.add_report("flags") do |report|
  report.category_filtering = true
  report.icon = 'flag'
  report.higher_is_better = false

  basic_report_about(
    report,
    ReviewableFlaggedPost,
    :count_by_date,
    report.start_date,
    report.end_date,
    report.category_id
  )

  countable = ReviewableFlaggedPost.scores_with_topics
  countable.merge!(Topic.in_category_and_subcategories(report.category_id)) if report.category_id

  add_counts report, countable, 'reviewable_scores.created_at'
end
