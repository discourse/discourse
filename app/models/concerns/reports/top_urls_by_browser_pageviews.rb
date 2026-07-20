# frozen_string_literal: true

module Reports::TopUrlsByBrowserPageviews
  extend ActiveSupport::Concern

  MAX_ROWS = 200

  class_methods do
    def report_top_urls_by_browser_pageviews(report)
      report.modes = [Report::MODES[:table]]

      report.labels = [
        {
          property: :normalized_url,
          type: :text,
          title: I18n.t("reports.top_urls_by_browser_pageviews.labels.normalized_url"),
        },
        {
          property: :count,
          type: :number,
          title: I18n.t("reports.top_urls_by_browser_pageviews.labels.count"),
        },
      ]

      count_expression = SiteSetting.login_required ? "logged_in_count" : "count"
      end_date_exclusive = report.end_date.to_date + 1

      report.data =
        DB
          .query(<<~SQL, start_date: report.start_date, end_date_exclusive:, limit: MAX_ROWS)
            WITH ranked AS (
              SELECT
                normalized_url,
                SUM(#{count_expression}) AS count,
                SUM(SUM(#{count_expression})) OVER () AS total
              FROM browser_pageview_url_daily_rollups
              WHERE date >= :start_date
                AND date < :end_date_exclusive
                AND normalized_url IS NOT NULL
              GROUP BY normalized_url
              HAVING SUM(#{count_expression}) > 0
            )
            SELECT normalized_url, count,
                   CASE WHEN total = 0 THEN 0
                        ELSE ROUND((count::numeric / total) * 100)::integer END AS percent
            FROM ranked
            ORDER BY count DESC, normalized_url ASC
            LIMIT :limit
          SQL
          .map do |row|
            { normalized_url: row.normalized_url, count: row.count, percent: row.percent }
          end
    end
  end
end
