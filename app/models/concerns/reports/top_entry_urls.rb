# frozen_string_literal: true

module Reports::TopEntryUrls
  extend ActiveSupport::Concern

  MAX_ROWS = 200

  class_methods do
    def report_top_entry_urls(report)
      report.modes = [Report::MODES[:table]]
      report.labels = [
        {
          properties: %i[entry_url entry_url],
          type: :link,
          title: I18n.t("reports.top_entry_urls.labels.entry_url"),
        },
        { property: :count, type: :number, title: I18n.t("reports.top_entry_urls.labels.count") },
      ]

      count_sql = BrowserPageviewEvent.rollup_count_sql

      report.data =
        DB
          .query(
            <<~SQL,
              WITH ranked AS (
                SELECT
                  entry_url,
                  SUM(#{count_sql}) AS count,
                  SUM(SUM(#{count_sql})) OVER () AS total
                FROM browser_pageview_entry_url_daily_rollups
                WHERE date >= :start_date
                  AND date <= :end_date
                  AND entry_url IS NOT NULL
                GROUP BY entry_url
                HAVING SUM(#{count_sql}) > 0
              )
              SELECT
                entry_url,
                count,
                CASE
                  WHEN total = 0 THEN 0
                  ELSE ROUND((count::numeric / total) * 100)::integer
                END AS percent
              FROM ranked
              ORDER BY count DESC, entry_url ASC
              LIMIT :limit
            SQL
            start_date: report.start_date.to_date,
            end_date: report.end_date.to_date,
            limit: MAX_ROWS,
          )
          .map { |row| { entry_url: row.entry_url, count: row.count, percent: row.percent } }
    end
  end
end
