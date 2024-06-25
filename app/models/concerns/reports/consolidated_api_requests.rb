# frozen_string_literal: true

module Reports::ConsolidatedApiRequests
  extend ActiveSupport::Concern

  class_methods do
    def report_consolidated_api_requests(report)
      filters = %w[api user_api]

      report.modes = [:stacked_chart]

      requests =
        filters.map do |filter|
          color = filter == "api" ? report.colors[:turquoise] : report.colors[:lime]

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
