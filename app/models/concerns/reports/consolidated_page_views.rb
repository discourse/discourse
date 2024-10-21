# frozen_string_literal: true

module Reports::ConsolidatedPageViews
  extend ActiveSupport::Concern

  class_methods do
    # NOTE: This report is superseded by "SiteTraffic". Eventually once
    # use_legacy_pageviews is always false or no longer needed, and users
    # no longer rely on the data in this old report in the transition period,
    # we can delete this.
    def report_consolidated_page_views(report)
      filters = %w[page_view_logged_in page_view_anon page_view_crawler]

      report.modes = [:stacked_chart]

      requests =
        filters.map do |filter|
          color = report.colors[:turquoise]
          color = report.colors[:lime] if filter == "page_view_anon"
          color = report.colors[:purple] if filter == "page_view_crawler"

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
