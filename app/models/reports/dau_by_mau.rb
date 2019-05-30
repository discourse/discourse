# frozen_string_literal: true

Report.add_report("dau_by_mau") do |report|
  report.labels = [
    {
      type: :date,
      property: :x,
      title: I18n.t("reports.default.labels.day")
    },
    {
      type: :percent,
      property: :y,
      title: I18n.t("reports.default.labels.percent")
    },
  ]

  report.average = true
  report.percent = true

  data_points = UserVisit.count_by_active_users(report.start_date, report.end_date)

  report.data = []

  compute_dau_by_mau = Proc.new { |data_point|
    if data_point["mau"] == 0
      0
    else
      ((data_point["dau"].to_f / data_point["mau"].to_f) * 100).ceil(2)
    end
  }

  dau_avg = Proc.new { |start_date, end_date|
    data_points = UserVisit.count_by_active_users(start_date, end_date)
    if !data_points.empty?
      sum = data_points.sum { |data_point| compute_dau_by_mau.call(data_point) }
      (sum.to_f / data_points.count.to_f).ceil(2)
    end
  }

  data_points.each do |data_point|
    report.data << { x: data_point["date"], y: compute_dau_by_mau.call(data_point) }
  end

  if report.facets.include?(:prev_period)
    report.prev_period = dau_avg.call(report.prev_start_date, report.prev_end_date)
  end

  if report.facets.include?(:prev30Days)
    report.prev30Days = dau_avg.call(report.start_date - 30.days, report.start_date)
  end
end
