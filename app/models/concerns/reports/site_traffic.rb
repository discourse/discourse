# frozen_string_literal: true

module Reports::SiteTraffic
  extend ActiveSupport::Concern

  SERIES_COLORS = {
    "page_view_logged_in_browser" => "#4B3CE0",
    "page_view_anon_browser" => "#9C8DEC",
    "page_view_crawler" => "#D5CDF7",
    "page_view_likely_crawler" => "#B3AAC9",
    "page_view_embed" => "#E6E1F8",
    "page_view_other" => "#E84A5F",
  }.freeze

  class_methods do
    def report_site_traffic(report)
      report.modes = [Report::MODES[:stacked_chart]]

      first_browser_pageview_date =
        DB.query_single(
          <<~SQL,
      SELECT date FROM application_requests
      WHERE req_type = :page_view_logged_in_browser OR req_type = :page_view_anon_browser ORDER BY date LIMIT 1
      SQL
          page_view_logged_in_browser: ApplicationRequest.req_types[:page_view_logged_in_browser],
          page_view_anon_browser: ApplicationRequest.req_types[:page_view_anon_browser],
        ).first

      likely_crawlers_enabled = UpcomingChanges.enabled?(:improved_crawler_detection)

      data =
        DB.query(
          <<~SQL,
            WITH likely_crawlers AS (
              SELECT
                date,
                COALESCE(SUM(count) FILTER (WHERE logged_in), 0)::bigint AS logged_in,
                COALESCE(SUM(count) FILTER (WHERE NOT logged_in), 0)::bigint AS anonymous
              FROM browser_pageview_crawler_daily_rollups
              WHERE :likely_crawlers_enabled
                AND date >= :start_date
                AND date <= :end_date
              GROUP BY date
            )
            SELECT
              ar.date,
              GREATEST(
                0,
                SUM(CASE WHEN ar.req_type = :page_view_logged_in_browser THEN ar.count ELSE 0 END)
                  - COALESCE(MAX(lc.logged_in), 0)
              ) AS page_view_logged_in_browser,
              GREATEST(
                0,
                SUM(CASE WHEN ar.req_type = :page_view_anon_browser THEN ar.count ELSE 0 END)
                  - COALESCE(MAX(lc.anonymous), 0)
              ) AS page_view_anon_browser,
              (COALESCE(MAX(lc.logged_in), 0) + COALESCE(MAX(lc.anonymous), 0)) AS page_view_likely_crawler,
              SUM(CASE WHEN ar.req_type = :page_view_crawler THEN ar.count ELSE 0 END) AS page_view_crawler,
              SUM(CASE WHEN ar.req_type = :page_view_embed THEN ar.count ELSE 0 END) AS page_view_embed,
              SUM(
                CASE WHEN ar.req_type = :page_view_anon THEN ar.count
                    WHEN ar.req_type = :page_view_logged_in THEN ar.count
                    WHEN ar.req_type = :page_view_anon_browser THEN -ar.count
                    WHEN ar.req_type = :page_view_logged_in_browser THEN -ar.count
                    ELSE 0
                END
              ) AS page_view_other
            FROM application_requests ar
            LEFT JOIN likely_crawlers lc ON lc.date = ar.date
            WHERE ar.date >= :start_date AND ar.date <= :end_date AND ar.date >= :first_browser_pageview_date

            GROUP BY ar.date
            ORDER BY ar.date ASC
          SQL
          start_date: report.start_date,
          end_date: report.end_date,
          likely_crawlers_enabled: likely_crawlers_enabled,
          page_view_anon: ApplicationRequest.req_types[:page_view_anon],
          page_view_crawler: ApplicationRequest.req_types[:page_view_crawler],
          page_view_logged_in: ApplicationRequest.req_types[:page_view_logged_in],
          page_view_anon_browser: ApplicationRequest.req_types[:page_view_anon_browser],
          page_view_logged_in_browser: ApplicationRequest.req_types[:page_view_logged_in_browser],
          page_view_embed: ApplicationRequest.req_types[:page_view_embed],
          first_browser_pageview_date: first_browser_pageview_date,
        )

      report.data = [
        {
          req: "page_view_logged_in_browser",
          label: I18n.t("reports.site_traffic.xaxis.page_view_logged_in_browser"),
          color: SERIES_COLORS.fetch("page_view_logged_in_browser"),
          data: data.map { |row| { x: row.date, y: row.page_view_logged_in_browser } },
        },
        {
          req: "page_view_anon_browser",
          label: I18n.t("reports.site_traffic.xaxis.page_view_anon_browser"),
          color: SERIES_COLORS.fetch("page_view_anon_browser"),
          data: data.map { |row| { x: row.date, y: row.page_view_anon_browser } },
        },
      ]

      if likely_crawlers_enabled
        report.data << {
          req: "page_view_likely_crawler",
          label: I18n.t("reports.site_traffic.xaxis.page_view_likely_crawler"),
          color: SERIES_COLORS.fetch("page_view_likely_crawler"),
          data: data.map { |row| { x: row.date, y: row.page_view_likely_crawler } },
        }
      end

      report.data << {
        req: "page_view_crawler",
        label: I18n.t("reports.site_traffic.xaxis.page_view_crawler"),
        color: SERIES_COLORS.fetch("page_view_crawler"),
        data: data.map { |row| { x: row.date, y: row.page_view_crawler } },
      }

      if EmbeddableHost.exists?
        report.data << {
          req: "page_view_embed",
          label: I18n.t("reports.site_traffic.xaxis.page_view_embed"),
          color: SERIES_COLORS.fetch("page_view_embed"),
          data: data.map { |row| { x: row.date, y: row.page_view_embed } },
        }
      end

      report.data << {
        req: "page_view_other",
        label: I18n.t("reports.site_traffic.xaxis.page_view_other"),
        color: SERIES_COLORS.fetch("page_view_other"),
        data: data.map { |row| { x: row.date, y: row.page_view_other } },
      }
    end
  end
end
