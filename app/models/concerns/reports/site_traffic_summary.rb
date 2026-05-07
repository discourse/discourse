# frozen_string_literal: true

module Reports::SiteTrafficSummary
  extend ActiveSupport::Concern

  class_methods do
    def report_site_traffic_summary(report)
      report.modes = [Report::MODES[:stacked_chart]]

      # Pick the human-pageview req_types based on the site's pageview-tracking
      # mode. Legacy sites use `page_view_logged_in` / `page_view_anon`; modern
      # sites use the browser-detected variants. Crawler counts are the same in
      # both modes. The SQL aliases are kept stable (`page_view_logged_in_browser`,
      # `page_view_anon_browser`, `page_view_crawler`) so the frontend doesn't
      # need to know which mode the site is in.
      legacy = SiteSetting.use_legacy_pageviews
      logged_in_req_type =
        ApplicationRequest.req_types[legacy ? :page_view_logged_in : :page_view_logged_in_browser]
      anon_req_type =
        ApplicationRequest.req_types[legacy ? :page_view_anon : :page_view_anon_browser]
      crawler_req_type = ApplicationRequest.req_types[:page_view_crawler]

      first_browser_pageview_date =
        DB.query_single(
          <<~SQL,
            SELECT date FROM application_requests
            WHERE req_type = :logged_in_req_type OR req_type = :anon_req_type
            ORDER BY date LIMIT 1
          SQL
          logged_in_req_type: logged_in_req_type,
          anon_req_type: anon_req_type,
        ).first

      # Generate one row per day in the selected range, joining against
      # application_requests. Days that have no row in application_requests
      # return zero counts. This guarantees the response always contains an
      # entry for every day in the period — the chart can rely on
      # complete data without needing to fill gaps client-side.
      data =
        DB.query(
          <<~SQL,
            SELECT
              d.date,
              COALESCE(SUM(CASE WHEN ar.req_type = :logged_in_req_type THEN ar.count ELSE 0 END), 0) AS page_view_logged_in_browser,
              COALESCE(SUM(CASE WHEN ar.req_type = :anon_req_type THEN ar.count ELSE 0 END), 0) AS page_view_anon_browser,
              COALESCE(SUM(CASE WHEN ar.req_type = :crawler_req_type THEN ar.count ELSE 0 END), 0) AS page_view_crawler
            FROM (
              SELECT generate_series(:start_date::date, :end_date::date, '1 day'::interval)::date AS date
            ) d
            LEFT JOIN application_requests ar ON ar.date = d.date
            GROUP BY d.date
            ORDER BY d.date ASC
          SQL
          start_date: report.start_date,
          end_date: report.end_date,
          logged_in_req_type: logged_in_req_type,
          anon_req_type: anon_req_type,
          crawler_req_type: crawler_req_type,
        )

      prior_period_length = report.end_date.to_date - report.start_date.to_date
      prior_end_date = report.start_date.to_date - 1
      prior_start_date = prior_end_date - prior_period_length

      prior_totals =
        DB.query_hash(
          <<~SQL,
            SELECT
              COALESCE(SUM(CASE WHEN req_type = :logged_in_req_type THEN count ELSE 0 END), 0) AS page_view_logged_in_browser,
              COALESCE(SUM(CASE WHEN req_type = :anon_req_type THEN count ELSE 0 END), 0) AS page_view_anon_browser,
              COALESCE(SUM(CASE WHEN req_type = :crawler_req_type THEN count ELSE 0 END), 0) AS page_view_crawler
            FROM application_requests
            WHERE date >= :start_date AND date <= :end_date
          SQL
          start_date: prior_start_date,
          end_date: prior_end_date,
          logged_in_req_type: logged_in_req_type,
          anon_req_type: anon_req_type,
          crawler_req_type: crawler_req_type,
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
