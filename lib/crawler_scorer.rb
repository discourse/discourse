# frozen_string_literal: true

class CrawlerScorer
  BOT_SCORE_THRESHOLD = 60

  AUTOMATION_UA_SCORE = 100

  KNOWN_ASN_SCORE = 15

  VELOCITY_LOW = 150
  VELOCITY_MEDIUM = 300
  VELOCITY_HIGH = 600
  VELOCITY_LOW_SCORE = 10
  VELOCITY_MEDIUM_SCORE = 20
  VELOCITY_HIGH_SCORE = 50

  CHURN_LOW_MIN_SESSIONS = 5
  CHURN_HIGH_MIN_SESSIONS = 10
  CHURN_MAX_AVG_EVENTS = 2
  CHURN_LOW_SCORE = 10
  CHURN_HIGH_SCORE = 20

  RAPID_NAV_MIN_GAPS = 10
  RAPID_NAV_MAX_MEDIAN_SECONDS = 5
  RAPID_NAV_SCORE = 15

  REFERRER_MIN_EVENTS = 5
  REFERRER_LOW_RATIO = 0.5
  REFERRER_HIGH_RATIO = 0.8
  REFERRER_LOW_SCORE = 5
  REFERRER_HIGH_SCORE = 10

  HUMAN_ACTIVITY_SCORE = -40

  def self.score!(window_start:, window_end:)
    crawler_asns = SiteSetting.crawler_asns_map.map(&:to_i)

    ActiveRecord::Base.transaction do
      DB.exec(
        SQL,
        window_start: window_start,
        window_end: window_end,
        ua_regex: SiteSetting.crawler_automation_user_agents,
        crawler_asns: crawler_asns,
        hostname: Discourse.current_hostname,
        automation_ua_score: AUTOMATION_UA_SCORE,
        known_asn_score: KNOWN_ASN_SCORE,
        velocity_low: VELOCITY_LOW,
        velocity_medium: VELOCITY_MEDIUM,
        velocity_high: VELOCITY_HIGH,
        velocity_low_score: VELOCITY_LOW_SCORE,
        velocity_medium_score: VELOCITY_MEDIUM_SCORE,
        velocity_high_score: VELOCITY_HIGH_SCORE,
        churn_low_min_sessions: CHURN_LOW_MIN_SESSIONS,
        churn_high_min_sessions: CHURN_HIGH_MIN_SESSIONS,
        churn_max_avg_events: CHURN_MAX_AVG_EVENTS,
        churn_low_score: CHURN_LOW_SCORE,
        churn_high_score: CHURN_HIGH_SCORE,
        rapid_nav_min_gaps: RAPID_NAV_MIN_GAPS,
        rapid_nav_max_median_seconds: RAPID_NAV_MAX_MEDIAN_SECONDS,
        rapid_nav_score: RAPID_NAV_SCORE,
        referrer_min_events: REFERRER_MIN_EVENTS,
        referrer_low_ratio: REFERRER_LOW_RATIO,
        referrer_high_ratio: REFERRER_HIGH_RATIO,
        referrer_low_score: REFERRER_LOW_SCORE,
        referrer_high_score: REFERRER_HIGH_SCORE,
        human_activity_score: HUMAN_ACTIVITY_SCORE,
      )
    end
  end

  SQL = <<~SQL
    WITH events AS (
      SELECT id, session_id, ip_address, user_agent, referrer, asn, created_at, source
      FROM browser_pageview_events
      WHERE created_at >= :window_start
        AND created_at <  :window_end
    ),

    -- Per-heuristic stats are partitioned by source as well as ip/ua so that
    -- pageviews recorded through different transports (e.g. piggyback vs
    -- beacon) never inflate one another's velocity, churn or navigation gaps.
    ipua_stats AS (
      SELECT
        ip_address,
        user_agent,
        source,
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
      GROUP BY ip_address, user_agent, source
    ),

    gaps AS (
      SELECT
        ip_address,
        user_agent,
        source,
        EXTRACT(EPOCH FROM created_at - LAG(created_at) OVER (
          PARTITION BY ip_address, user_agent, source ORDER BY created_at
        )) AS gap_seconds
      FROM events
    ),

    median_gap AS (
      SELECT
        ip_address,
        user_agent,
        source,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY gap_seconds)
          AS median_gap_seconds,
        COUNT(*) AS gap_count
      FROM gaps
      WHERE gap_seconds IS NOT NULL
      GROUP BY ip_address, user_agent, source
    ),

    breakdown AS (
      SELECT
        e.id,
        CASE
          WHEN :ua_regex <> '' AND e.user_agent ~* :ua_regex THEN :automation_ua_score
          ELSE 0
        END AS automation_ua_score,
        CASE
          WHEN e.asn = ANY(ARRAY[:crawler_asns]::int[]) THEN :known_asn_score
          ELSE 0
        END AS known_asn_score,
        CASE
          WHEN iu.pageviews >= :velocity_high   THEN :velocity_high_score
          WHEN iu.pageviews >= :velocity_medium THEN :velocity_medium_score
          WHEN iu.pageviews >= :velocity_low    THEN :velocity_low_score
          ELSE 0
        END AS velocity_score,
        CASE
          WHEN iu.distinct_sessions >= :churn_high_min_sessions
            AND iu.pageviews::float / NULLIF(iu.distinct_sessions, 0) <= :churn_max_avg_events
            THEN :churn_high_score
          WHEN iu.distinct_sessions >= :churn_low_min_sessions
            AND iu.pageviews::float / NULLIF(iu.distinct_sessions, 0) <= :churn_max_avg_events
            THEN :churn_low_score
          ELSE 0
        END AS churn_score,
        CASE
          WHEN mg.gap_count >= :rapid_nav_min_gaps
            AND mg.median_gap_seconds < :rapid_nav_max_median_seconds
            THEN :rapid_nav_score
          ELSE 0
        END AS rapid_nav_score,
        CASE
          WHEN iu.pageviews >= :referrer_min_events
            AND iu.bad_referrer_ratio >= :referrer_high_ratio THEN :referrer_high_score
          WHEN iu.pageviews >= :referrer_min_events
            AND iu.bad_referrer_ratio >= :referrer_low_ratio  THEN :referrer_low_score
          ELSE 0
        END AS referrer_score,
        CASE
          WHEN se.session_id IS NOT NULL THEN :human_activity_score
          ELSE 0
        END AS engagement_score
      FROM events e
      LEFT JOIN ipua_stats iu USING (ip_address, user_agent, source)
      LEFT JOIN median_gap mg USING (ip_address, user_agent, source)
      LEFT JOIN browser_pageview_session_engagements se
        ON se.session_id = e.session_id
        AND (
          #{BrowserPageviewSessionEngagement::INTERACTION_COLUMNS.map { |column| "se.#{column} > 0" }.join(" OR ")}
        )
    ),

    totals AS (
      SELECT
        id,
        automation_ua_score,
        known_asn_score,
        velocity_score,
        churn_score,
        rapid_nav_score,
        referrer_score,
        engagement_score,
        GREATEST(
          0,
          automation_ua_score + known_asn_score + velocity_score + churn_score
            + rapid_nav_score + referrer_score + engagement_score
        ) AS score
      FROM breakdown
      WHERE automation_ua_score + known_asn_score + velocity_score + churn_score
        + rapid_nav_score + referrer_score > 0
    ),

    updated AS (
      UPDATE browser_pageview_events e
      SET score = t.score
      FROM totals t
      WHERE e.id = t.id
        AND (e.score IS NULL OR t.score > e.score)
      RETURNING e.id,
                t.automation_ua_score,
                t.known_asn_score,
                t.velocity_score,
                t.churn_score,
                t.rapid_nav_score,
                t.referrer_score,
                t.engagement_score
    )

    INSERT INTO browser_pageview_event_scores (
      event_id,
      automation_ua_score,
      known_asn_score,
      velocity_score,
      churn_score,
      rapid_nav_score,
      referrer_score,
      engagement_score
    )
    SELECT
      id,
      automation_ua_score,
      known_asn_score,
      velocity_score,
      churn_score,
      rapid_nav_score,
      referrer_score,
      engagement_score
    FROM updated
    ON CONFLICT (event_id) DO UPDATE
    SET automation_ua_score = EXCLUDED.automation_ua_score,
        known_asn_score     = EXCLUDED.known_asn_score,
        velocity_score      = EXCLUDED.velocity_score,
        churn_score         = EXCLUDED.churn_score,
        rapid_nav_score     = EXCLUDED.rapid_nav_score,
        referrer_score      = EXCLUDED.referrer_score,
        engagement_score    = EXCLUDED.engagement_score;
  SQL
end
