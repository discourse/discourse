# frozen_string_literal: true

Report.add_report('signups') do |report|
  report.icon = 'user-plus'

  group_filter = report.filters.dig(:group)
  report.add_filter('group', default: group_filter)

  if group_filter
    basic_report_about report, User.real, :count_by_signup_date, report.start_date, report.end_date, group_filter
    add_counts report, User.real, 'users.created_at'
  else
    report_about report, User.real, :count_by_signup_date
  end
end
