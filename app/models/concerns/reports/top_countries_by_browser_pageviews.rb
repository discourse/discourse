# frozen_string_literal: true

module Reports::TopCountriesByBrowserPageviews
  extend ActiveSupport::Concern

  EXCLUDED_COUNTRY_CODES = %w[ZZ T1 A1 A2 O1 XX EU AP].freeze
  MAX_ROWS = 200

  class_methods do
    def report_top_countries_by_browser_pageviews(report)
      report.modes = [Report::MODES[:table]]

      report.labels = [
        {
          property: :country_code,
          type: :text,
          title: I18n.t("reports.top_countries_by_browser_pageviews.labels.country_code"),
        },
        {
          property: :count,
          type: :number,
          title: I18n.t("reports.top_countries_by_browser_pageviews.labels.count"),
        },
      ]

      count_expr = SiteSetting.login_required ? "logged_in_count" : "count"
      end_date_exclusive = report.end_date.to_date + 1

      sql = <<~SQL
        WITH ranked AS (
          SELECT
            country_code,
            SUM(#{count_expr}) AS count,
            SUM(SUM(#{count_expr})) OVER () AS total
          FROM browser_pageview_country_daily_rollups
          WHERE date >= :start_date
            AND date < :end_date_exclusive
          GROUP BY country_code
          HAVING SUM(#{count_expr}) > 0
        )
        SELECT country_code, count,
               CASE WHEN total = 0 THEN 0
                    ELSE ROUND((count::numeric / total) * 100)::integer END AS percent
        FROM ranked
        WHERE country_code IS NOT NULL
          AND country_code NOT IN (:excluded_codes)
        ORDER BY count DESC, country_code ASC
        LIMIT :limit
      SQL

      report.data =
        DB
          .query(
            sql,
            start_date: report.start_date,
            end_date_exclusive: end_date_exclusive,
            excluded_codes: EXCLUDED_COUNTRY_CODES,
            limit: MAX_ROWS,
          )
          .map { |row| { country_code: row.country_code, count: row.count, percent: row.percent } }
    end
  end
end
