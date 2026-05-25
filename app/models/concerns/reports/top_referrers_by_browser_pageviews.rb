# frozen_string_literal: true

module Reports::TopReferrersByBrowserPageviews
  extend ActiveSupport::Concern

  class_methods do
    def report_top_referrers_by_browser_pageviews(report)
      report.modes = [Report::MODES[:table]]

      report.labels = [
        {
          property: :normalized_referrer,
          type: :text,
          title: I18n.t("reports.top_referrers_by_browser_pageviews.labels.normalized_referrer"),
        },
        {
          property: :count,
          type: :number,
          title: I18n.t("reports.top_referrers_by_browser_pageviews.labels.count"),
        },
      ]

      count_expr = SiteSetting.login_required ? "logged_in_count" : "count"
      end_date_exclusive = report.end_date.to_date + 1

      sql = <<~SQL
        WITH ranked AS (
          SELECT
            normalized_referrer,
            SUM(#{count_expr}) AS count,
            SUM(SUM(#{count_expr})) OVER () AS total
          FROM browser_pageview_referrer_daily_rollups
          WHERE date >= :start_date
            AND date < :end_date_exclusive
          GROUP BY normalized_referrer
        )
        SELECT normalized_referrer, count,
               CASE WHEN total = 0 THEN 0
                    ELSE ROUND((count::numeric / total) * 100)::integer END AS percent
        FROM ranked
        WHERE normalized_referrer IS NOT NULL
        ORDER BY count DESC, normalized_referrer ASC
        LIMIT :limit
      SQL

      report.data =
        DB
          .query(
            sql,
            start_date: report.start_date,
            end_date_exclusive: end_date_exclusive,
            limit: report.limit || 50,
          )
          .map do |row|
            { normalized_referrer: row.normalized_referrer, count: row.count, percent: row.percent }
          end
    end
  end
end
