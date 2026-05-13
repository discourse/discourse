# frozen_string_literal: true

class CrawlerScorer
  def self.score_anonymous!(window_start:, window_end:)
    crawler_asns = SiteSetting.crawler_asns_map.map(&:to_i)

    ActiveRecord::Base.transaction do
      DB.exec(
        SQL,
        window_start: window_start,
        window_end: window_end,
        ua_regex: SiteSetting.crawler_automation_user_agents,
        crawler_asns: crawler_asns,
        hostname: Discourse.current_hostname,
      )
    end
  end

  SQL = <<~SQL
    WITH events AS (
      SELECT id, session_id, ip_address, user_agent, referrer, asn, created_at
      FROM browser_pageview_events
      WHERE user_id IS NULL
        AND created_at >= :window_start
        AND created_at <  :window_end
    ),

    ipua_stats AS (
      SELECT
        ip_address,
        user_agent,
        COUNT(*) AS pageviews,
        COUNT(DISTINCT session_id) AS distinct_sessions,
        AVG(
          CASE
            WHEN referrer IS NULL THEN 1.0
            WHEN substring(referrer from '^https?://([^/]+)') = :hostname THEN 0.0
            ELSE 1.0
          END
        ) AS bad_referrer_ratio
      FROM events
      GROUP BY ip_address, user_agent
    ),

    gaps AS (
      SELECT
        ip_address,
        user_agent,
        EXTRACT(EPOCH FROM created_at - LAG(created_at) OVER (
          PARTITION BY ip_address, user_agent ORDER BY created_at
        )) AS gap_seconds
      FROM events
    ),

    median_gap AS (
      SELECT
        ip_address,
        user_agent,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY gap_seconds)
          AS median_gap_seconds,
        COUNT(*) AS gap_count
      FROM gaps
      WHERE gap_seconds IS NOT NULL
      GROUP BY ip_address, user_agent
    ),

    totals AS (
      SELECT
        e.id,
        CASE
          WHEN :ua_regex <> '' AND e.user_agent ~* :ua_regex THEN 50
          ELSE 0
        END
        + CASE
            WHEN e.asn = ANY(ARRAY[:crawler_asns]::int[]) THEN 35
            ELSE 0
          END
        + CASE
            WHEN iu.pageviews >= 240 THEN 35
            WHEN iu.pageviews >= 120 THEN 20
            WHEN iu.pageviews >=  60 THEN 10
            ELSE 0
          END
        + CASE
            WHEN iu.distinct_sessions >= 10
              AND iu.pageviews::float / NULLIF(iu.distinct_sessions, 0) <= 2 THEN 20
            WHEN iu.distinct_sessions >=  5
              AND iu.pageviews::float / NULLIF(iu.distinct_sessions, 0) <= 2 THEN 10
            ELSE 0
          END
        + CASE
            WHEN mg.gap_count >= 10 AND mg.median_gap_seconds < 2 THEN 15
            ELSE 0
          END
        + CASE
            WHEN iu.pageviews >= 5 AND iu.bad_referrer_ratio >= 0.8 THEN 10
            WHEN iu.pageviews >= 5 AND iu.bad_referrer_ratio >= 0.5 THEN  5
            ELSE 0
          END
          AS score
      FROM events e
      LEFT JOIN ipua_stats iu USING (ip_address, user_agent)
      LEFT JOIN median_gap mg USING (ip_address, user_agent)
    )

    UPDATE browser_pageview_events e
    SET score = t.score
    FROM totals t
    WHERE e.id = t.id
      AND t.score > COALESCE(e.score, 0);
  SQL
end
