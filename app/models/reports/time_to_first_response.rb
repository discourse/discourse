Report.add_report("time_to_first_response") do |report|
  report.category_filtering = true
  report.icon = 'reply'
  report.higher_is_better = false
  report.data = []
  Topic.time_to_first_response_per_day(report.start_date, report.end_date, category_id: report.category_id).each do |r|
    report.data << { x: r["date"], y: r["hours"].to_f.round(2) }
  end
  report.total = Topic.time_to_first_response_total(category_id: report.category_id)
  report.prev30Days = Topic.time_to_first_response_total(start_date: report.start_date - 30.days, end_date: report.start_date, category_id: report.category_id)
end
