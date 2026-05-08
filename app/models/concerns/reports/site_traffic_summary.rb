# frozen_string_literal: true

module Reports::SiteTrafficSummary
  extend ActiveSupport::Concern

  class_methods do
    def report_site_traffic_summary(report)
      report.modes = [Report::MODES[:stacked_chart]]

      crawler_req_type = ApplicationRequest.req_types[:page_view_crawler]
      include_anonymous = !SiteSetting.login_required

      first_browser_pageview_date =
        DB.query_single(<<~SQL, include_anonymous: include_anonymous).first
          SELECT date FROM pageview_daily_aggregates_beacon
          WHERE :include_anonymous OR is_logged_in
          ORDER BY date LIMIT 1
        SQL

      # Generate one row per day in the selected range, joining against
      # beacon aggregates for human pageviews and application_requests for
      # crawlers. Days with no rows return zero counts, so the chart gets a
      # complete day spine without client-side gap filling.
      data =
        DB.query(
          <<~SQL,
            WITH human_pageviews AS (
              SELECT
                date,
                COALESCE(SUM(CASE WHEN is_logged_in THEN count ELSE 0 END), 0) AS page_view_logged_in_browser,
                COALESCE(SUM(CASE WHEN NOT is_logged_in THEN count ELSE 0 END), 0) AS page_view_anon_browser
              FROM pageview_daily_aggregates_beacon
              WHERE date >= :start_date AND date <= :end_date AND (:include_anonymous OR is_logged_in)
              GROUP BY date
            ),
            crawler_pageviews AS (
              SELECT date, COALESCE(SUM(count), 0) AS page_view_crawler
              FROM application_requests
              WHERE date >= :start_date AND date <= :end_date AND req_type = :crawler_req_type
              GROUP BY date
            )
            SELECT
              d.date,
              COALESCE(human_pageviews.page_view_logged_in_browser, 0) AS page_view_logged_in_browser,
              COALESCE(human_pageviews.page_view_anon_browser, 0) AS page_view_anon_browser,
              COALESCE(crawler_pageviews.page_view_crawler, 0) AS page_view_crawler
            FROM (
              SELECT generate_series(:start_date::date, :end_date::date, '1 day'::interval)::date AS date
            ) d
            LEFT JOIN human_pageviews ON human_pageviews.date = d.date
            LEFT JOIN crawler_pageviews ON crawler_pageviews.date = d.date
            ORDER BY d.date ASC
          SQL
          start_date: report.start_date,
          end_date: report.end_date,
          crawler_req_type: crawler_req_type,
          include_anonymous: include_anonymous,
        )

      prior_period_length = report.end_date.to_date - report.start_date.to_date
      prior_end_date = report.start_date.to_date - 1
      prior_start_date = prior_end_date - prior_period_length

      prior_totals =
        DB.query_hash(
          <<~SQL,
            WITH human_pageviews AS (
              SELECT
                COALESCE(SUM(CASE WHEN is_logged_in THEN count ELSE 0 END), 0) AS page_view_logged_in_browser,
                COALESCE(SUM(CASE WHEN NOT is_logged_in THEN count ELSE 0 END), 0) AS page_view_anon_browser
              FROM pageview_daily_aggregates_beacon
              WHERE date >= :start_date AND date <= :end_date AND (:include_anonymous OR is_logged_in)
            ),
            crawler_pageviews AS (
              SELECT COALESCE(SUM(count), 0) AS page_view_crawler
              FROM application_requests
              WHERE date >= :start_date AND date <= :end_date AND req_type = :crawler_req_type
            )
            SELECT
              human_pageviews.page_view_logged_in_browser,
              human_pageviews.page_view_anon_browser,
              crawler_pageviews.page_view_crawler
            FROM human_pageviews, crawler_pageviews
          SQL
          start_date: prior_start_date,
          end_date: prior_end_date,
          crawler_req_type: crawler_req_type,
          include_anonymous: include_anonymous,
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

      top_countries =
        DB.query(
          <<~SQL,
            WITH countries AS (
              SELECT country_code, SUM(count) AS count
              FROM pageview_daily_aggregates_beacon
              WHERE date >= :start_date AND date <= :end_date AND country_code IS NOT NULL AND (:include_anonymous OR is_logged_in)
              GROUP BY country_code
            ),
            totals AS (
              SELECT COALESCE(SUM(count), 0) AS total FROM countries
            )
            SELECT
              countries.country_code,
              countries.count,
              CASE
                WHEN totals.total = 0 THEN 0
                ELSE ROUND((countries.count::numeric / totals.total) * 100)
              END AS percent
            FROM countries, totals
            ORDER BY countries.count DESC, countries.country_code ASC
            LIMIT 5
          SQL
          start_date: report.start_date,
          end_date: report.end_date,
          include_anonymous: include_anonymous,
        )

      top_referrers =
        DB.query(
          <<~SQL,
            WITH referrers AS (
              SELECT source_name, SUM(count) AS count
              FROM pageview_daily_aggregates_beacon
              WHERE date >= :start_date AND date <= :end_date AND source_name <> :direct_source_name AND (:include_anonymous OR is_logged_in)
              GROUP BY source_name
            ),
            totals AS (
              SELECT COALESCE(SUM(count), 0) AS total FROM referrers
            )
            SELECT
              referrers.source_name,
              referrers.count,
              CASE
                WHEN totals.total = 0 THEN 0
                ELSE ROUND((referrers.count::numeric / totals.total) * 100)
              END AS percent
            FROM referrers, totals
            ORDER BY referrers.count DESC, referrers.source_name ASC
            LIMIT 5
          SQL
          start_date: report.start_date,
          end_date: report.end_date,
          direct_source_name: PageviewDailyAggregate::DIRECT_SOURCE_NAME,
          include_anonymous: include_anonymous,
        )

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
        top_countries:
          top_countries.map do |row|
            { country_code: row.country_code, count: row.count.to_i, percent: row.percent.to_i }
          end,
        top_referrers:
          top_referrers.map do |row|
            { source_name: row.source_name, count: row.count.to_i, percent: row.percent.to_i }
          end,
      }
    end
  end
end
