# frozen_string_literal: true

Report.add_report("mobile_visits") do |report|
  basic_report_about report, UserVisit, :mobile_by_day, report.start_date, report.end_date
  report.total = UserVisit.where(mobile: true).count
  report.prev30Days = UserVisit.where(mobile: true).where("visited_at >= ? and visited_at < ?", report.start_date - 30.days, report.start_date).count
end
