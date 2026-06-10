# frozen_string_literal: true

class BrowserPageviewSessionDailyRollup < ActiveRecord::Base
  # A browser tab keeps one session_id for its whole lifetime, which can be
  # days for a parked tab, so the tab id is only a correlation key. A logical
  # visit ends after this much inactivity: a later pageview in the same tab
  # starts a new visit, and an exit ping can extend a visit's final page by
  # at most this long.
  VISIT_INACTIVITY_SECONDS = 30.minutes.to_i

  BOUNCE_THRESHOLD_SECONDS = 10

  # Visits can span midnight: scanning starts a day before the requested
  # range so a visit attributed to the range's first day still sees the
  # pageviews it accrued after midnight on the previous aggregation run.
  SCAN_LOOKBACK = 1.day

  private_constant :VISIT_INACTIVITY_SECONDS, :BOUNCE_THRESHOLD_SECONDS, :SCAN_LOOKBACK

  # Durations are bounded elapsed time, not active engagement time. A page
  # backgrounded after 5 seconds and revisited 25 minutes later is charged
  # the full gap, because pageview timestamps and exit ping receipts are the
  # only signals: nothing records when the page lost or regained visibility
  # in between. Measuring true foreground time requires the client to report
  # visible/hidden intervals, which this deliberately avoids so durations
  # never depend on a client-computed value.
  #
  # Pings landing after the visit's inactivity window are evidence the page
  # outlived the visit (a parked tab focused hours later), not engagement
  # inside it: they credit the final page with at most the inactivity cap
  # and only when no in-window ping pinned an earlier departure. Without
  # this, a 5-second bounce whose tab is touched the next day would
  # retroactively become a 30-minute non-bounce.
  # Gaps and visit boundaries both come from one pass over the tab's
  # pageviews in (created_at, id) order: a row whose gap to the next pageview
  # is NULL or beyond the inactivity timeout is its visit's final pageview,
  # and the remaining gaps are by definition the in-visit ones. This keeps
  # the whole aggregation on a single sort, which is where most of its time
  # goes at production volume.
  def self.aggregate(start_date:, end_date:)
    DB.exec(
      <<~SQL,
        WITH tab_events AS (
          SELECT
            session_id,
            id,
            created_at,
            user_id,
            CASE
              WHEN LAG(created_at) OVER tab_order IS NULL THEN 1
              WHEN EXTRACT(EPOCH FROM (created_at - LAG(created_at) OVER tab_order)) >
                :inactivity_seconds THEN 1
              ELSE 0
            END AS starts_new_visit,
            EXTRACT(EPOCH FROM (LEAD(created_at) OVER tab_order - created_at)) AS gap_seconds
          FROM browser_pageview_events
          WHERE created_at >= :scan_start AND created_at < :scan_end
          WINDOW tab_order AS (PARTITION BY session_id ORDER BY created_at, id)
        ),
        visit_events AS (
          SELECT
            *,
            SUM(starts_new_visit) OVER (
              PARTITION BY session_id
              ORDER BY created_at, id
            ) AS visit_number
          FROM tab_events
        ),
        visits AS (
          SELECT
            session_id,
            visit_number,
            MIN(created_at) AS first_pageview_at,
            MAX(created_at) AS last_pageview_at,
            MAX(id) FILTER (
              WHERE gap_seconds IS NULL OR gap_seconds > :inactivity_seconds
            ) AS last_pageview_id,
            COUNT(*) AS pageviews_count,
            BOOL_OR(user_id IS NOT NULL) AS logged_in,
            COALESCE(
              SUM(gap_seconds) FILTER (WHERE gap_seconds <= :inactivity_seconds),
              0
            ) AS gaps_seconds
          FROM visit_events
          GROUP BY session_id, visit_number
        ),
        measured_visits AS (
          SELECT
            visits.*,
            visits.gaps_seconds + CASE
              WHEN pings.last_ping_within_visit_at IS NOT NULL THEN LEAST(
                GREATEST(
                  EXTRACT(EPOCH FROM (pings.last_ping_within_visit_at - visits.last_pageview_at)),
                  0
                ),
                :inactivity_seconds
              )
              WHEN pings.pinged_after_visit THEN :inactivity_seconds
              ELSE 0
            END AS duration_seconds
          FROM visits
          LEFT JOIN LATERAL (
            SELECT
              MAX(created_at) FILTER (
                WHERE created_at <= visits.last_pageview_at + make_interval(secs => :inactivity_seconds)
              ) AS last_ping_within_visit_at,
              COUNT(*) FILTER (
                WHERE created_at > visits.last_pageview_at + make_interval(secs => :inactivity_seconds)
              ) > 0 AS pinged_after_visit
            FROM browser_pageview_engagements
            WHERE event_id = visits.last_pageview_id
          ) pings ON true
        )
        INSERT INTO browser_pageview_session_daily_rollups
          (date, logged_in, sessions_count, bounced_count, total_duration_seconds)
        SELECT
          first_pageview_at::date AS date,
          logged_in,
          COUNT(*) AS sessions_count,
          COUNT(*) FILTER (
            WHERE pageviews_count = 1 AND duration_seconds < :bounce_threshold
          ) AS bounced_count,
          COALESCE(SUM(duration_seconds), 0)::bigint AS total_duration_seconds
        FROM measured_visits
        WHERE first_pageview_at >= :start_date AND first_pageview_at < :scan_end
        GROUP BY 1, 2
        ON CONFLICT (date, logged_in) DO UPDATE
        SET sessions_count = EXCLUDED.sessions_count,
            bounced_count = EXCLUDED.bounced_count,
            total_duration_seconds = EXCLUDED.total_duration_seconds
      SQL
      start_date: start_date.to_date,
      scan_start: start_date.to_date - SCAN_LOOKBACK,
      scan_end: end_date.to_date + 1,
      inactivity_seconds: VISIT_INACTIVITY_SECONDS,
      bounce_threshold: BOUNCE_THRESHOLD_SECONDS,
    )
  end
end

# == Schema Information
#
# Table name: browser_pageview_session_daily_rollups
#
#  id                     :bigint           not null, primary key
#  bounced_count          :bigint           not null
#  date                   :date             not null
#  logged_in              :boolean          not null
#  sessions_count         :bigint           not null
#  total_duration_seconds :bigint           not null
#
# Indexes
#
#  idx_bpsd_rollups_date_logged_in_unique  (date,logged_in) UNIQUE
#
