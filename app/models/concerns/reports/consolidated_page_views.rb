# frozen_string_literal: true

module Reports::ConsolidatedPageViews
  extend ActiveSupport::Concern

  class_methods do
    def report_consolidated_page_views(report)
      filters = %w[page_view_logged_in page_view_anon page_view_crawler]

      report.modes = [:stacked_chart]

      tertiary = ColorScheme.hex_for_name("tertiary") || "0088cc"
      danger = ColorScheme.hex_for_name("danger") || "e45735"

      requests =
        filters.map do |filter|
          color = report.rgba_color(tertiary)

          color = report.lighten_color(tertiary, 0.25) if filter == "page_view_anon"

          color = report.rgba_color(danger, 0.75) if filter == "page_view_crawler"

          {
            req: filter,
            label: I18n.t("reports.consolidated_page_views.xaxis.#{filter}"),
            color: color,
            data: ApplicationRequest.where(req_type: ApplicationRequest.req_types[filter]),
          }
        end

      requests.each do |request|
        request[:data] = request[:data]
          .where("date >= ? AND date <= ?", report.start_date, report.end_date)
          .order(date: :asc)
          .group(:date)
          .sum(:count)
          .map { |date, count| { x: date, y: count } }
      end

      report.data = requests
    end
  end
end
