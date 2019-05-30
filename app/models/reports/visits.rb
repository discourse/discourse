# frozen_string_literal: true

Report.add_report('visits') do |report|
  group_filter = report.filters.dig(:group)
  report.add_filter('group', default: group_filter)

  report.icon = 'user'

  basic_report_about report, UserVisit, :by_day, report.start_date, report.end_date, group_filter
  add_counts report, UserVisit, 'visited_at'

  report.prev30Days = UserVisit.where('visited_at >= ? and visited_at < ?', report.start_date - 30.days, report.start_date).count
end
