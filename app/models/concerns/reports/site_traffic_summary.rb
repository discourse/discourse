# frozen_string_literal: true

module Reports::SiteTrafficSummary
  extend ActiveSupport::Concern

  class_methods do
    def report_site_traffic_summary(report)
      report.modes = [Report::MODES[:stacked_chart]]

      first_browser_pageview_date =
        DB.query_single(
          <<~SQL,
            SELECT date FROM application_requests
            WHERE req_type = :page_view_logged_in_browser OR req_type = :page_view_anon_browser
            ORDER BY date LIMIT 1
          SQL
          page_view_logged_in_browser: ApplicationRequest.req_types[:page_view_logged_in_browser],
          page_view_anon_browser: ApplicationRequest.req_types[:page_view_anon_browser],
        ).first

      data =
        DB.query(
          <<~SQL,
            SELECT
              date,
              SUM(CASE WHEN req_type = :page_view_logged_in_browser THEN count ELSE 0 END) AS page_view_logged_in_browser,
              SUM(CASE WHEN req_type = :page_view_anon_browser THEN count ELSE 0 END) AS page_view_anon_browser,
              SUM(CASE WHEN req_type = :page_view_crawler THEN count ELSE 0 END) AS page_view_crawler
            FROM application_requests
            WHERE date >= :start_date AND date <= :end_date
            GROUP BY date
            ORDER BY date ASC
          SQL
          start_date: report.start_date,
          end_date: report.end_date,
          page_view_crawler: ApplicationRequest.req_types[:page_view_crawler],
          page_view_anon_browser: ApplicationRequest.req_types[:page_view_anon_browser],
          page_view_logged_in_browser: ApplicationRequest.req_types[:page_view_logged_in_browser],
        )

      prior_period_length = report.end_date.to_date - report.start_date.to_date
      prior_end_date = report.start_date.to_date - 1
      prior_start_date = prior_end_date - prior_period_length

      prior_totals =
        DB.query_hash(
          <<~SQL,
            SELECT
              COALESCE(SUM(CASE WHEN req_type = :page_view_logged_in_browser THEN count ELSE 0 END), 0) AS page_view_logged_in_browser,
              COALESCE(SUM(CASE WHEN req_type = :page_view_anon_browser THEN count ELSE 0 END), 0) AS page_view_anon_browser,
              COALESCE(SUM(CASE WHEN req_type = :page_view_crawler THEN count ELSE 0 END), 0) AS page_view_crawler
            FROM application_requests
            WHERE date >= :start_date AND date <= :end_date
          SQL
          start_date: prior_start_date,
          end_date: prior_end_date,
          page_view_crawler: ApplicationRequest.req_types[:page_view_crawler],
          page_view_anon_browser: ApplicationRequest.req_types[:page_view_anon_browser],
          page_view_logged_in_browser: ApplicationRequest.req_types[:page_view_logged_in_browser],
        ).first ||
          {
            "page_view_logged_in_browser" => 0,
            "page_view_anon_browser" => 0,
            "page_view_crawler" => 0,
          }

      report.data = [
        {
          req: "page_view_logged_in_browser",
          label: I18n.t("reports.site_traffic_summary.xaxis.page_view_logged_in_browser"),
          color: report.colors[:turquoise],
          data: data.map { |row| { x: row.date, y: row.page_view_logged_in_browser } },
        },
        {
          req: "page_view_anon_browser",
          label: I18n.t("reports.site_traffic_summary.xaxis.page_view_anon_browser"),
          color: report.colors[:lime],
          data: data.map { |row| { x: row.date, y: row.page_view_anon_browser } },
        },
        {
          req: "page_view_crawler",
          label: I18n.t("reports.site_traffic_summary.xaxis.page_view_crawler"),
          color: report.colors[:purple],
          data: data.map { |row| { x: row.date, y: row.page_view_crawler } },
        },
      ]

      current_totals = {
        page_view_logged_in_browser: data.sum { |row| row.page_view_logged_in_browser.to_i },
        page_view_anon_browser: data.sum { |row| row.page_view_anon_browser.to_i },
        page_view_crawler: data.sum { |row| row.page_view_crawler.to_i },
      }

      report.related_data = {
        current_totals: current_totals,
        prior_totals: {
          page_view_logged_in_browser: prior_totals["page_view_logged_in_browser"].to_i,
          page_view_anon_browser: prior_totals["page_view_anon_browser"].to_i,
          page_view_crawler: prior_totals["page_view_crawler"].to_i,
        },
        first_browser_pageview_date: first_browser_pageview_date&.iso8601,
        prior_start_date: prior_start_date.iso8601,
        prior_end_date: prior_end_date.iso8601,
      }
    end
  end
end
