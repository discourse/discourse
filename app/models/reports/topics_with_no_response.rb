Report.add_report("topics_with_no_response") do |report|
  report.category_filtering = true
  report.data = []
  Topic.with_no_response_per_day(report.start_date, report.end_date, report.category_id).each do |r|
    report.data << { x: r["date"], y: r["count"].to_i }
  end
  report.total = Topic.with_no_response_total(category_id: report.category_id)
  report.prev30Days = Topic.with_no_response_total(start_date: report.start_date - 30.days, end_date: report.start_date, category_id: report.category_id)
end
