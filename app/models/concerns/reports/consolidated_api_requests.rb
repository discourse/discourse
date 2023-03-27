# frozen_string_literal: true

module Reports::ConsolidatedApiRequests
  extend ActiveSupport::Concern

  class_methods do
    def report_consolidated_api_requests(report)
      filters = %w[api user_api]

      report.modes = [:stacked_chart]

      tertiary = ColorScheme.hex_for_name("tertiary") || "0088cc"
      danger = ColorScheme.hex_for_name("danger") || "e45735"

      requests =
        filters.map do |filter|
          color = filter == "api" ? report.rgba_color(tertiary) : report.rgba_color(danger)

          {
            req: filter,
            label: I18n.t("reports.consolidated_api_requests.xaxis.#{filter}"),
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
