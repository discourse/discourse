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
  ANONYMOUS_MISSING_ENGAGEMENT_HIGH_SCORE = 50
  ENGAGEMENT_LOOKBACK = 6.hours

  DISTRIBUTED_TRAFFIC_LOOKBACK = 24.hours
  DISTRIBUTED_TRAFFIC_MIN_PAGEVIEWS = 100
  DISTRIBUTED_TRAFFIC_MIN_IPS = 20
  DISTRIBUTED_TRAFFIC_MIN_SESSION_RATIO = 0.98
  DISTRIBUTED_TRAFFIC_MAX_ENGAGEMENT_RATIO = 0.005
  DISTRIBUTED_TRAFFIC_SCORE = 60

  def self.enabled?
    UpcomingChanges.enabled?(:improved_crawler_detection)
  end

  def self.likely_crawler_condition(table: nil)
    prefix = table ? "#{table}." : ""
    "#{prefix}score > #{BOT_SCORE_THRESHOLD}"
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
        site_hostnames: site_hostnames,
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
        anonymous_missing_engagement_high_score: ANONYMOUS_MISSING_ENGAGEMENT_HIGH_SCORE,
        distributed_traffic_lookback_start: window_end - DISTRIBUTED_TRAFFIC_LOOKBACK,
        distributed_traffic_min_pageviews: DISTRIBUTED_TRAFFIC_MIN_PAGEVIEWS,
        distributed_traffic_min_ips: DISTRIBUTED_TRAFFIC_MIN_IPS,
        distributed_traffic_min_session_ratio: DISTRIBUTED_TRAFFIC_MIN_SESSION_RATIO,
        distributed_traffic_max_engagement_ratio: DISTRIBUTED_TRAFFIC_MAX_ENGAGEMENT_RATIO,
        distributed_traffic_score: DISTRIBUTED_TRAFFIC_SCORE,
      )
    end
  end

  def self.site_hostnames
    (RailsMultisite::ConnectionManagement.current_db_hostnames + [Discourse.current_hostname])
      .filter_map { |hostname| BrowserPageviewEventUrlNormalizer.normalize_host(hostname) }
      .uniq
  end
  private_class_method :site_hostnames

  def self.internal_referrer_sql(column)
    "split_part(split_part(#{column}, '/', 1), '?', 1) = ANY(ARRAY[:site_hostnames]::text[])"
  end
  private_class_method :internal_referrer_sql

  SQL = <<~SQL
    WITH events AS (
      SELECT
        e.id,
        e.session_id,
        e.ip_address,
        e.user_agent,
        e.referrer,
        e.normalized_referrer,
        e.asn,
        e.url,
        e.user_id,
        e.created_at,
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
        )
      GROUP BY e.ip_address, e.user_agent
    ),

    cohort_pageviews AS (
      SELECT
        e.id,
        e.created_at,
        e.user_agent,
        e.ip_address,
        e.session_id,
        e.asn,
        e.referrer,
        e.normalized_referrer,
        (#{internal_referrer_sql("e.normalized_referrer")}) AS internal_referrer,
        (se.session_id IS NOT NULL)::int AS engaged
      FROM browser_pageview_events e
      LEFT JOIN browser_pageview_session_engagements se
        ON se.session_id = e.session_id
        AND #{BrowserPageviewSessionEngagement.engaged_sql("se")}
      WHERE e.created_at >= :distributed_traffic_lookback_start
        AND e.created_at < :window_end
        AND e.user_id IS NULL
        AND EXISTS (
          SELECT 1 FROM events w
          WHERE w.user_id IS NULL AND w.user_agent = e.user_agent
        )
    ),

    referrer_sessions AS (
      SELECT DISTINCT ON (session_id, user_agent) session_id, user_agent, normalized_referrer
      FROM cohort_pageviews
      WHERE normalized_referrer IS NOT NULL
        AND referrer ~* '^https?://'
        AND NOT internal_referrer
      ORDER BY session_id, user_agent, created_at, id
    ),

    cohort_memberships AS (
      SELECT 'asn' AS kind, asn::text AS key, user_agent, ip_address, session_id, engaged
      FROM cohort_pageviews
      WHERE asn IS NOT NULL
      UNION ALL
      SELECT 'referrer', referral.normalized_referrer, pageview.user_agent,
        pageview.ip_address, pageview.session_id, pageview.engaged
      FROM referrer_sessions referral
      JOIN cohort_pageviews pageview USING (session_id, user_agent)
    ),

    distributed_cohorts AS (
      SELECT kind, key, user_agent
      FROM cohort_memberships
      GROUP BY kind, key, user_agent
      HAVING COUNT(*) >= :distributed_traffic_min_pageviews
        AND COUNT(DISTINCT ip_address) >= :distributed_traffic_min_ips
        AND COUNT(DISTINCT session_id)::float / COUNT(*) >= :distributed_traffic_min_session_ratio
        AND AVG(engaged) <= :distributed_traffic_max_engagement_ratio
    ),

    distributed_events AS (
      SELECT e.id
      FROM events e
      JOIN distributed_cohorts cohort
        ON cohort.kind = 'asn' AND cohort.key = e.asn::text AND cohort.user_agent = e.user_agent
      UNION
      SELECT e.id
      FROM events e
      JOIN referrer_sessions USING (session_id, user_agent, normalized_referrer)
      JOIN distributed_cohorts cohort
        ON cohort.kind = 'referrer' AND cohort.key = e.normalized_referrer AND cohort.user_agent = e.user_agent
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

    session_stats AS (
      SELECT
        session_id,
        COUNT(DISTINCT ip_address) AS distinct_ips,
        EXTRACT(EPOCH FROM MAX(created_at) - MIN(created_at)) AS span_seconds
      FROM events
      GROUP BY session_id
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
          WHEN e.user_id IS NULL AND NOT e.engaged AND de.id IS NOT NULL
            THEN :distributed_traffic_score
          ELSE 0
        END AS distributed_traffic_score,
        CASE
          WHEN e.engaged THEN 0
          WHEN e.user_id IS NULL AND ie.no_engagement_ratio >= :missing_engagement_high_ratio
            THEN :anonymous_missing_engagement_high_score
          WHEN ie.no_engagement_ratio >= :missing_engagement_high_ratio
            THEN :missing_engagement_high_score
          WHEN ie.no_engagement_ratio >= :missing_engagement_low_ratio
            THEN :missing_engagement_low_score
          ELSE 0
        END AS engagement_score
      FROM events e
      LEFT JOIN ipua_stats iu USING (ip_address, user_agent)
      LEFT JOIN ipua_engagement ie USING (ip_address, user_agent)
      LEFT JOIN median_gap mg USING (ip_address, user_agent)
      LEFT JOIN session_stats ss USING (session_id)
      LEFT JOIN distributed_events de ON de.id = e.id
    ),

    signal_totals AS (
      SELECT
        *,
        automation_ua_score + known_asn_score + datacenter_asn_score + single_request_no_referrer_score + stale_browser_score + velocity_score + churn_score
          + rapid_nav_score + ip_rotation_score + referrer_score + distributed_traffic_score AS signal_score
      FROM breakdown
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
        distributed_traffic_score,
        CASE WHEN signal_score > 0 THEN engagement_score ELSE 0 END AS engagement_score,
        CASE WHEN signal_score > 0 THEN GREATEST(0, signal_score + engagement_score) ELSE 0 END AS score
      FROM signal_totals
      -- Preserve burst-only scores as their supporting events leave the window.
      WHERE signal_score > 0 OR EXISTS (
        SELECT 1 FROM browser_pageview_event_scores previous
        WHERE previous.event_id = signal_totals.id
          AND previous.distributed_traffic_score > 0
      )
    ),

    updated AS (
      UPDATE browser_pageview_events e
      SET score = t.score
      FROM totals t
      LEFT JOIN browser_pageview_event_scores previous ON previous.event_id = t.id
      WHERE e.id = t.id
        AND (
          e.score IS DISTINCT FROM t.score OR
          ROW(
            previous.automation_ua_score,
            previous.known_asn_score,
            previous.datacenter_asn_score,
            previous.single_request_no_referrer_score,
            previous.stale_browser_score,
            previous.velocity_score,
            previous.churn_score,
            previous.rapid_nav_score,
            previous.ip_rotation_score,
            previous.referrer_score,
            previous.distributed_traffic_score,
            previous.engagement_score
          ) IS DISTINCT FROM ROW(
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
            t.distributed_traffic_score,
            t.engagement_score
          )
        )
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
                t.distributed_traffic_score,
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
      distributed_traffic_score,
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
      distributed_traffic_score,
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
        distributed_traffic_score = EXCLUDED.distributed_traffic_score,
        engagement_score    = EXCLUDED.engagement_score;
  SQL
end
