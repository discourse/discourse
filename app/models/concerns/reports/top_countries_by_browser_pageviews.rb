# frozen_string_literal: true

module Reports::TopCountriesByBrowserPageviews
  extend ActiveSupport::Concern

  EXCLUDED_COUNTRY_CODES = %w[ZZ T1 A1 A2 O1 XX EU AP].freeze

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

      user_filter_sql = SiteSetting.login_required ? "AND user_id IS NOT NULL" : ""
      end_date_exclusive = report.end_date.to_date + 1

      sql = <<~SQL
        WITH ranked AS (
          SELECT
            country_code,
            COUNT(*) AS count,
            SUM(COUNT(*)) OVER () AS total
          FROM browser_pageview_events
          WHERE created_at >= :start_date
            AND created_at < :end_date_exclusive
            #{user_filter_sql}
          GROUP BY country_code
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
            limit: report.limit || 50,
          )
          .map { |row| { country_code: row.country_code, count: row.count, percent: row.percent } }
    end
  end
end
