# frozen_string_literal: true

class BrowserPageviewSessionEngagementDailyRollup < ActiveRecord::Base
  BOUNCE_ENGAGED_SECONDS_THRESHOLD = 10
  private_constant :BOUNCE_ENGAGED_SECONDS_THRESHOLD

  def self.aggregate(start_date:, end_date:, source: BrowserPageviewEvent.rollup_source)
    start_date = start_date.to_date
    end_date = end_date.to_date + 1

    transaction do
      DB.exec(<<~SQL, start_date:, end_date:, source:)
        DELETE FROM browser_pageview_session_engagement_daily_rollups rollup
        WHERE rollup.date >= :start_date
          AND rollup.date < :end_date
          AND EXISTS (
            SELECT 1
            FROM browser_pageview_events
            WHERE created_at >= rollup.date
              AND created_at < rollup.date + 1
              AND source = :source
          )
      SQL

      DB.exec(
        <<~SQL,
        WITH active_sessions AS (
          SELECT DISTINCT session_id
          FROM browser_pageview_events
          WHERE created_at >= :start_date
            AND created_at < LEAST(:end_date::timestamp, :session_started_before::timestamp)
            AND source = :source
        ),
        session_pageviews AS (
          SELECT
            bpe.session_id,
            MIN(bpe.created_at)::date AS date,
            COUNT(*) AS pageview_count,
            bool_or(bpe.user_id IS NOT NULL) AS logged_in
          FROM browser_pageview_events bpe
          JOIN active_sessions ON active_sessions.session_id = bpe.session_id
          WHERE bpe.source = :source
          GROUP BY bpe.session_id
          HAVING MIN(bpe.created_at) >= :start_date
        )
        INSERT INTO browser_pageview_session_engagement_daily_rollups
          (date, logged_in, sessions, bounced, engaged_seconds_total)
        SELECT
          session_pageviews.date,
          session_pageviews.logged_in,
          COUNT(*) AS sessions,
          COUNT(*) FILTER (
            WHERE session_pageviews.pageview_count = 1
              AND COALESCE(engagement.engaged_seconds, 0) < :bounce_threshold
          ) AS bounced,
          COALESCE(SUM(engagement.engaged_seconds), 0) AS engaged_seconds_total
        FROM session_pageviews
        LEFT JOIN browser_pageview_session_engagements engagement
          ON engagement.session_id = session_pageviews.session_id
        GROUP BY session_pageviews.date, session_pageviews.logged_in
      SQL
        start_date:,
        end_date:,
        session_started_before: BrowserPageviewSessionEngagement::BEACON_SETTLE_PERIOD.ago,
        bounce_threshold: BOUNCE_ENGAGED_SECONDS_THRESHOLD,
        source:,
      )
    end
  end
end

# == Schema Information
#
# Table name: browser_pageview_session_engagement_daily_rollups
#
#  id                    :bigint           not null, primary key
#  bounced               :bigint           not null
#  date                  :date             not null
#  engaged_seconds_total :bigint           not null
#  logged_in             :boolean          not null
#  sessions              :bigint           not null
#
# Indexes
#
#  idx_bpse_rollups_date_logged_in_unique  (date,logged_in) UNIQUE
#
