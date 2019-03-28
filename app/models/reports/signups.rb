Report.add_report("signups") do |report|
  report.group_filtering = true

  report.icon = 'user-plus'

  if report.group_id
    basic_report_about report, User.real, :count_by_signup_date, report.start_date, report.end_date, report.group_id
    add_counts report, User.real, 'users.created_at'
  else
    report_about report, User.real, :count_by_signup_date
  end

  # add_prev_data report, User.real, :count_by_signup_date, report.prev_start_date, report.prev_end_date
end
