Report.add_report("profile_views") do |report|
  report.group_filtering = true
  start_date = report.start_date
  end_date = report.end_date
  basic_report_about report, UserProfileView, :profile_views_by_day, start_date, end_date, report.group_id

  report.total = UserProfile.sum(:views)
  report.prev30Days = UserProfileView.where("viewed_at >= ? AND viewed_at < ?", start_date - 30.days, start_date + 1).count
end
