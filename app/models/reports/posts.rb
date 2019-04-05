Report.add_report("posts") do |report|
  report.modes = [:table, :chart]
  report.category_filtering = true
  basic_report_about report, Post, :public_posts_count_per_day, report.start_date, report.end_date, report.category_id
  countable = Post.public_posts.where(post_type: Post.types[:regular])
  if report.category_id
    countable = countable.joins(:topic).merge(Topic.in_category_and_subcategories(report.category_id))
  end
  add_counts report, countable, 'posts.created_at'
end
