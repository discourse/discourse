# frozen_string_literal: true

Report.add_report("daily_engaged_users") do |report|
  report.average = true

  report.data = []

  data = UserAction.count_daily_engaged_users(report.start_date, report.end_date)

  if report.facets.include?(:prev30Days)
    prev30DaysData = UserAction.count_daily_engaged_users(report.start_date - 30.days, report.start_date)
    report.prev30Days = prev30DaysData.sum { |k, v| v }
  end

  if report.facets.include?(:total)
    report.total = UserAction.count_daily_engaged_users
  end

  if report.facets.include?(:prev_period)
    prev_data = UserAction.count_daily_engaged_users(report.prev_start_date, report.prev_end_date)

    prev = prev_data.sum { |k, v| v }
    if prev > 0
      prev = prev / ((report.end_date - report.start_date) / 1.day)
    end
    report.prev_period = prev
  end

  data.each do |key, value|
    report.data << { x: key, y: value }
  end
end
