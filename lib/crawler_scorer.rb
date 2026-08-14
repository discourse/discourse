# frozen_string_literal: true

class CrawlerScorer
  BOT_SCORE_THRESHOLD = 55

  AUTOMATION_UA_SCORE = 100

  KNOWN_ASN_SCORE = 30
  DATACENTER_ASN_SCORE = 10
  SINGLE_REQUEST_NO_REFERRER_SCORE = 10
  SINGLE_REQUEST_LOCALE_PARAM_BONUS = 5
  STALE_BROWSER_SCORE = 5

  VELOCITY_LOW = 150
  VELOCITY_MEDIUM = 300
  VELOCITY_HIGH = 600
  VELOCITY_LOW_SCORE = 15
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

  IP_ROTATION_MIN_IPS = 3
  IP_ROTATION_MAX_SECONDS_PER_CHANGE = 300
  IP_ROTATION_SCORE = 30

  REFERRER_MIN_EVENTS = 5
  REFERRER_LOW_RATIO = 0.5
  REFERRER_HIGH_RATIO = 0.8
  REFERRER_LOW_SCORE = 5
  REFERRER_HIGH_SCORE = 10

  MISSING_ENGAGEMENT_LOW_RATIO = 0.5
  MISSING_ENGAGEMENT_HIGH_RATIO = 0.9
  MISSING_ENGAGEMENT_LOW_SCORE = 20
  MISSING_ENGAGEMENT_HIGH_SCORE = 40
  ENGAGEMENT_LOOKBACK = 6.hours

  def self.enabled?
    UpcomingChanges.enabled?(:improved_crawler_detection)
  end

  def self.likely_crawler_condition(table: nil)
    prefix = table ? "#{table}." : ""
    "#{prefix}score > #{BOT_SCORE_THRESHOLD}"
  end

  # Anonymous searches carry no pageview session, so they are matched to scored
  # traffic by address and user agent within this window.
  SEARCH_CORRELATION_WINDOW = 1.hour

  def self.flag_search_logs!(window_start:, window_end:)
    DB.exec(
      <<~SQL,
        UPDATE search_logs
        SET likely_crawler = TRUE
        WHERE search_logs.user_id IS NULL
          AND NOT search_logs.likely_crawler
          AND search_logs.created_at >= :window_start
          AND search_logs.created_at < :window_end
          AND search_logs.ip_address IS NOT NULL
          AND search_logs.user_agent IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM browser_pageview_events event
            WHERE event.ip_address = search_logs.ip_address
              AND event.user_agent = left(search_logs.user_agent, :max_user_agent_length)
              AND #{likely_crawler_condition(table: "event")}
              AND event.created_at >= search_logs.created_at - :correlation_window::interval
              AND event.created_at <= search_logs.created_at + :correlation_window::interval
          )
      SQL
      window_start: window_start,
      window_end: window_end,
      correlation_window: "#{SEARCH_CORRELATION_WINDOW.to_i} seconds",
      max_user_agent_length: BrowserPageviewEvent::MAX_USER_AGENT_LENGTH,
    )
  end

  def self.score!(window_start:, window_end:)
    crawler_asns = SiteSetting.crawler_asns_map.map(&:to_i)
    crawler_detection_datacenter_asns =
      SiteSetting.crawler_detection_datacenter_asns_map.map(&:to_i)

    ActiveRecord::Base.transaction do
      DB.exec(
        SQL,
        window_start: window_start,
        window_end: window_end,
        ua_regex: SiteSetting.crawler_automation_user_agents,
        crawler_asns: crawler_asns,
        crawler_detection_datacenter_asns: crawler_detection_datacenter_asns,
        hostname: Discourse.current_hostname,
        automation_ua_score: AUTOMATION_UA_SCORE,
        known_asn_score: KNOWN_ASN_SCORE,
        datacenter_asn_score: DATACENTER_ASN_SCORE,
        single_request_no_referrer_score: SINGLE_REQUEST_NO_REFERRER_SCORE,
        single_request_locale_param_bonus: SINGLE_REQUEST_LOCALE_PARAM_BONUS,
        stale_browser_score: STALE_BROWSER_SCORE,
        stale_chromium_major_version_cutoff:
          SiteSetting.crawler_stale_chromium_major_version_cutoff,
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
        ip_rotation_min_ips: IP_ROTATION_MIN_IPS,
        ip_rotation_max_seconds_per_change: IP_ROTATION_MAX_SECONDS_PER_CHANGE,
        ip_rotation_score: IP_ROTATION_SCORE,
        referrer_min_events: REFERRER_MIN_EVENTS,
        referrer_low_ratio: REFERRER_LOW_RATIO,
        referrer_high_ratio: REFERRER_HIGH_RATIO,
        referrer_low_score: REFERRER_LOW_SCORE,
        referrer_high_score: REFERRER_HIGH_SCORE,
        engagement_lookback_start: window_end - ENGAGEMENT_LOOKBACK,
        missing_engagement_low_ratio: MISSING_ENGAGEMENT_LOW_RATIO,
        missing_engagement_high_ratio: MISSING_ENGAGEMENT_HIGH_RATIO,
        missing_engagement_low_score: MISSING_ENGAGEMENT_LOW_SCORE,
        missing_engagement_high_score: MISSING_ENGAGEMENT_HIGH_SCORE,
      )
    end
  end

  SQL = <<~SQL
    WITH events AS (
      SELECT
        e.id,
        e.session_id,
        e.ip_address,
        e.user_agent,
        e.referrer,
        e.asn,
        e.url,
        e.created_at,
        e.source,
        (se.session_id IS NOT NULL) AS engaged
      FROM browser_pageview_events e
      LEFT JOIN browser_pageview_session_engagements se
        ON se.session_id = e.session_id
        AND #{BrowserPageviewSessionEngagement.engaged_sql("se")}
      WHERE e.created_at >= :window_start
        AND e.created_at <  :window_end
    ),

    ipua_engagement AS (
      SELECT
        e.ip_address,
        e.user_agent,
        e.source,
        AVG(CASE WHEN se.session_id IS NOT NULL THEN 0.0 ELSE 1.0 END)
          AS no_engagement_ratio
      FROM browser_pageview_events e
      LEFT JOIN browser_pageview_session_engagements se
        ON se.session_id = e.session_id
        AND #{BrowserPageviewSessionEngagement.engaged_sql("se")}
      WHERE e.created_at >= :engagement_lookback_start
        AND e.created_at <  :window_end
        AND EXISTS (
          SELECT 1
          FROM events w
          WHERE w.ip_address = e.ip_address
            AND w.user_agent = e.user_agent
            AND w.source = e.source
        )
      GROUP BY e.ip_address, e.user_agent, e.source
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

    session_stats AS (
      SELECT
        session_id,
        source,
        COUNT(DISTINCT ip_address) AS distinct_ips,
        EXTRACT(EPOCH FROM MAX(created_at) - MIN(created_at)) AS span_seconds
      FROM events
      GROUP BY session_id, source
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
          WHEN e.asn = ANY(ARRAY[:crawler_detection_datacenter_asns]::int[]) THEN :datacenter_asn_score
          ELSE 0
        END AS datacenter_asn_score,
        CASE
          WHEN iu.pageviews = 1
            AND e.referrer IS NULL
            AND NOT e.engaged
            AND e.url ~ '[?&]#{Discourse::LOCALE_PARAM}(=|&|$)'
            THEN :single_request_no_referrer_score + :single_request_locale_param_bonus
          WHEN iu.pageviews = 1
            AND e.referrer IS NULL
            AND NOT e.engaged THEN :single_request_no_referrer_score
          ELSE 0
        END AS single_request_no_referrer_score,
        CASE
          WHEN NOT e.engaged
            AND e.user_agent ~ 'Chrome/[0-9]{1,3}'
            AND e.user_agent !~* 'HeadlessChrome'
            AND (substring(e.user_agent FROM 'Chrome/([0-9]{1,3})'))::int
              <= :stale_chromium_major_version_cutoff
            THEN :stale_browser_score
          ELSE 0
        END AS stale_browser_score,
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
          WHEN ss.distinct_ips >= :ip_rotation_min_ips
            AND (ss.distinct_ips - 1) * :ip_rotation_max_seconds_per_change
                  > GREATEST(ss.span_seconds, 1)
            THEN :ip_rotation_score
          ELSE 0
        END AS ip_rotation_score,
        CASE
          WHEN iu.pageviews >= :referrer_min_events
            AND iu.bad_referrer_ratio >= :referrer_high_ratio THEN :referrer_high_score
          WHEN iu.pageviews >= :referrer_min_events
            AND iu.bad_referrer_ratio >= :referrer_low_ratio  THEN :referrer_low_score
          ELSE 0
        END AS referrer_score,
        CASE
          WHEN e.engaged THEN 0
          WHEN ie.no_engagement_ratio >= :missing_engagement_high_ratio
            THEN :missing_engagement_high_score
          WHEN ie.no_engagement_ratio >= :missing_engagement_low_ratio
            THEN :missing_engagement_low_score
          ELSE 0
        END AS engagement_score
      FROM events e
      LEFT JOIN ipua_stats iu USING (ip_address, user_agent, source)
      LEFT JOIN ipua_engagement ie USING (ip_address, user_agent, source)
      LEFT JOIN median_gap mg USING (ip_address, user_agent, source)
      LEFT JOIN session_stats ss USING (session_id, source)
    ),

    totals AS (
      SELECT
        id,
        automation_ua_score,
        known_asn_score,
        datacenter_asn_score,
        single_request_no_referrer_score,
        stale_browser_score,
        velocity_score,
        churn_score,
        rapid_nav_score,
        ip_rotation_score,
        referrer_score,
        engagement_score,
        GREATEST(
          0,
          automation_ua_score + known_asn_score + datacenter_asn_score + single_request_no_referrer_score + stale_browser_score + velocity_score + churn_score
            + rapid_nav_score + ip_rotation_score + referrer_score + engagement_score
        ) AS score
      FROM breakdown
      WHERE automation_ua_score + known_asn_score + datacenter_asn_score + single_request_no_referrer_score + stale_browser_score + velocity_score + churn_score
        + rapid_nav_score + ip_rotation_score + referrer_score > 0
    ),

    updated AS (
      UPDATE browser_pageview_events e
      SET score = t.score
      FROM totals t
      WHERE e.id = t.id
        AND e.score IS DISTINCT FROM t.score
      RETURNING e.id,
                t.automation_ua_score,
                t.known_asn_score,
                t.datacenter_asn_score,
                t.single_request_no_referrer_score,
                t.stale_browser_score,
                t.velocity_score,
                t.churn_score,
                t.rapid_nav_score,
                t.ip_rotation_score,
                t.referrer_score,
                t.engagement_score
    )

    INSERT INTO browser_pageview_event_scores (
      event_id,
      automation_ua_score,
      known_asn_score,
      datacenter_asn_score,
      single_request_no_referrer_score,
      stale_browser_score,
      velocity_score,
      churn_score,
      rapid_nav_score,
      ip_rotation_score,
      referrer_score,
      engagement_score
    )
    SELECT
      id,
      automation_ua_score,
      known_asn_score,
      datacenter_asn_score,
      single_request_no_referrer_score,
      stale_browser_score,
      velocity_score,
      churn_score,
      rapid_nav_score,
      ip_rotation_score,
      referrer_score,
      engagement_score
    FROM updated
    ON CONFLICT (event_id) DO UPDATE
    SET automation_ua_score = EXCLUDED.automation_ua_score,
        known_asn_score     = EXCLUDED.known_asn_score,
        datacenter_asn_score = EXCLUDED.datacenter_asn_score,
        single_request_no_referrer_score = EXCLUDED.single_request_no_referrer_score,
        stale_browser_score = EXCLUDED.stale_browser_score,
        velocity_score      = EXCLUDED.velocity_score,
        churn_score         = EXCLUDED.churn_score,
        rapid_nav_score     = EXCLUDED.rapid_nav_score,
        ip_rotation_score   = EXCLUDED.ip_rotation_score,
        referrer_score      = EXCLUDED.referrer_score,
        engagement_score    = EXCLUDED.engagement_score;
  SQL
end
