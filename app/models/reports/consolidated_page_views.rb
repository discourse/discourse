# frozen_string_literal: true

Report.add_report("consolidated_page_views") do |report|
  filters = %w[
    page_view_logged_in
    page_view_anon
    page_view_crawler
  ]

  report.modes = [:stacked_chart]

  tertiary = ColorScheme.hex_for_name('tertiary') || '0088cc'
  danger = ColorScheme.hex_for_name('danger') || 'e45735'

  requests = filters.map do |filter|
    color = report.rgba_color(tertiary)

    if filter == "page_view_anon"
      color = report.lighten_color(tertiary, 0.25)
    end

    if filter == "page_view_crawler"
      color = report.rgba_color(danger, 0.75)
    end

    {
      req: filter,
      label: I18n.t("reports.consolidated_page_views.xaxis.#{filter}"),
      color: color,
      data: ApplicationRequest.where(req_type: ApplicationRequest.req_types[filter])
    }
  end

  requests.each do |request|
    request[:data] = request[:data].where('date >= ? AND date <= ?', report.start_date, report.end_date)
      .order(date: :asc)
      .group(:date)
      .sum(:count)
      .map { |date, count| { x: date, y: count } }
  end

  report.data = requests
end
