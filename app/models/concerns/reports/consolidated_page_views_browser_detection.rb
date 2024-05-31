# frozen_string_literal: true

module Reports::ConsolidatedPageViewsBrowserDetection
  extend ActiveSupport::Concern

  class_methods do
    def report_consolidated_page_views_browser_detection(report)
      report.modes = [:stacked_chart]

      data =
        DB.query(
          <<~SQL,
            SELECT
              date,
              SUM(CASE WHEN req_type = :page_view_logged_in_browser THEN count ELSE 0 END) AS page_view_logged_in_browser,
              SUM(CASE WHEN req_type = :page_view_anon_browser THEN count ELSE 0 END) AS page_view_anon_browser,
              SUM(CASE WHEN req_type = :page_view_crawler THEN count ELSE 0 END) AS page_view_crawler,
              SUM(
                CASE WHEN req_type = :page_view_anon THEN count
                    WHEN req_type = :page_view_logged_in THEN count
                    WHEN req_type = :page_view_anon_browser THEN -count
                    WHEN req_type = :page_view_logged_in_browser THEN -count
                    ELSE 0
                END
              ) AS page_view_other
            FROM application_requests
            WHERE date >= :start_date AND date <= :end_date
            GROUP BY date
            ORDER BY date ASC
          SQL
          start_date: report.start_date,
          end_date: report.end_date,
          page_view_anon: ApplicationRequest.req_types[:page_view_anon],
          page_view_crawler: ApplicationRequest.req_types[:page_view_crawler],
          page_view_logged_in: ApplicationRequest.req_types[:page_view_logged_in],
          page_view_anon_browser: ApplicationRequest.req_types[:page_view_anon_browser],
          page_view_logged_in_browser: ApplicationRequest.req_types[:page_view_logged_in_browser],
        )

      report.data = [
        {
          req: "page_view_logged_in_browser",
          label:
            I18n.t(
              "reports.consolidated_page_views_browser_detection.xaxis.page_view_logged_in_browser",
            ),
          color: report.colors[:turquoise],
          data: data.map { |row| { x: row.date, y: row.page_view_logged_in_browser } },
        },
        {
          req: "page_view_anon_browser",
          label:
            I18n.t(
              "reports.consolidated_page_views_browser_detection.xaxis.page_view_anon_browser",
            ),
          color: report.colors[:lime],
          data: data.map { |row| { x: row.date, y: row.page_view_anon_browser } },
        },
        {
          req: "page_view_crawler",
          label:
            I18n.t("reports.consolidated_page_views_browser_detection.xaxis.page_view_crawler"),
          color: report.colors[:purple],
          data: data.map { |row| { x: row.date, y: row.page_view_crawler } },
        },
        {
          req: "page_view_other",
          label: I18n.t("reports.consolidated_page_views_browser_detection.xaxis.page_view_other"),
          color: report.colors[:magenta],
          data: data.map { |row| { x: row.date, y: row.page_view_other } },
        },
      ]
    end
  end
end
