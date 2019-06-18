# frozen_string_literal: true

Report.add_report('posts') do |report|
  report.modes = [:table, :chart]

  category_filter = report.filters.dig(:category)
  report.add_filter('category', default: category_filter)

  basic_report_about report, Post, :public_posts_count_per_day, report.start_date, report.end_date, category_filter

  countable = Post.public_posts.where(post_type: Post.types[:regular])
  if category_filter
    countable = countable.joins(:topic).merge(Topic.in_category_and_subcategories(category_filter))
  end
  add_counts report, countable, 'posts.created_at'
end
