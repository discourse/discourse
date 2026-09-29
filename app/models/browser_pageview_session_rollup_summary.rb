# frozen_string_literal: true

class BrowserPageviewSessionRollupSummary < ActiveRecord::Base
  self.primary_key = :session_id

  BATCH_SIZE = 1_000
  STATUS_VERSION = 1
  private_constant :BATCH_SIZE, :STATUS_VERSION

  def self.refresh_recent!(start_date:, end_date:)
    seed_recent!(start_date:, end_date:) if !initialized?
    refresh_dirty!

    transaction do
      lock_daily_rollups!
      refresh_dirty!
      repair_older_dates!(start_date:)
      rebuild_recent!(start_date:, end_date:)
      DB.exec(<<~SQL, version: STATUS_VERSION)
        INSERT INTO browser_pageview_session_rollup_statuses (id, version, initialized_at)
        VALUES (1, :version, CURRENT_TIMESTAMP)
        ON CONFLICT (id) DO UPDATE
        SET version = EXCLUDED.version, initialized_at = EXCLUDED.initialized_at
      SQL
    end

    expire_clean!(start_date:)
  end

  def self.clear_uninitialized!
    transaction do
      lock_daily_rollups!
      DB.exec("DELETE FROM browser_pageview_session_rollup_summaries") if !initialized?
    end
  end

  def self.reconcile_manual_rebuild!(start_date:, end_date:)
    transaction do
      lock_daily_rollups!
      BrowserPageviewSessionEngagementDailyRollup.aggregate(start_date:, end_date:)
      return if !initialized?

      recent_start = 1.day.ago.to_date
      DB.exec(<<~SQL, start_date: recent_start)
        UPDATE browser_pageview_session_rollup_summaries
        SET dirty_generation = dirty_generation + 1
        WHERE first_pageview_at >= :start_date
      SQL
      refresh_dirty!
      rebuild_recent!(start_date: recent_start, end_date: Time.zone.today)
    end
  end

  def self.initialized?
    DB.query_single(<<~SQL, version: STATUS_VERSION).first.present?
      SELECT 1
      FROM browser_pageview_session_rollup_statuses
      WHERE id = 1 AND version = :version
    SQL
  end

  def self.verify_recent!(date:)
    return if !initialized?

    mismatch = DB.query_single(<<~SQL, date: date.to_date).first
          WITH active_sessions AS (
            SELECT DISTINCT session_id
            FROM browser_pageview_events
            WHERE created_at >= :date AND created_at < :date::date + 1
          ),
          source AS (
            SELECT
              active_sessions.session_id,
              stats.first_pageview_at,
              stats.pageview_count,
              stats.logged_in,
              stats.likely_crawler
            FROM active_sessions
            CROSS JOIN LATERAL (
              SELECT
                MIN(bpe.created_at) AS first_pageview_at,
                COUNT(*) AS pageview_count,
                bool_or(bpe.user_id IS NOT NULL) AS logged_in,
                COALESCE(
                  bool_or(#{CrawlerScorer.likely_crawler_condition(table: "bpe")}),
                  false
                ) AS likely_crawler
              FROM browser_pageview_events bpe
              WHERE bpe.session_id = active_sessions.session_id
            ) stats
            WHERE stats.first_pageview_at >= :date
              AND stats.first_pageview_at < :date::date + 1
          ),
          summaries AS (
            SELECT *
            FROM browser_pageview_session_rollup_summaries
            WHERE first_pageview_at >= :date
              AND first_pageview_at < :date::date + 1
          )
          SELECT 1
          FROM source
          FULL JOIN summaries summary
            ON summary.session_id = source.session_id
          LEFT JOIN browser_pageview_session_engagements engagement
            ON engagement.session_id = COALESCE(source.session_id, summary.session_id)
          WHERE (source.session_id IS NOT NULL AND summary.session_id IS NULL)
            OR (
              summary.dirty_generation = summary.refreshed_generation
              AND (
                source.session_id IS NULL
                OR
                (summary.first_pageview_at, summary.pageview_count, summary.logged_in,
                 summary.likely_crawler, summary.engaged_seconds)
                IS DISTINCT FROM
                (source.first_pageview_at, source.pageview_count, source.logged_in,
                 source.likely_crawler, COALESCE(engagement.engaged_seconds, 0))
              )
            )
          LIMIT 1
        SQL

    raise "Browser pageview session rollup differs from source for #{date}" if mismatch
  end

  def self.seed_recent!(start_date:, end_date:)
    DB.exec(<<~SQL, start_date:, end_date: end_date + 1)
      WITH active_sessions AS (
        SELECT DISTINCT session_id
        FROM browser_pageview_events
        WHERE created_at >= :start_date
          AND created_at < :end_date
      )
      INSERT INTO browser_pageview_session_rollup_summaries
        (
          session_id, first_pageview_at, pageview_count, logged_in,
          likely_crawler, engaged_seconds, dirty_generation, refreshed_generation
        )
      SELECT
        active_sessions.session_id,
        stats.first_pageview_at,
        stats.pageview_count,
        stats.logged_in,
        COALESCE(stats.likely_crawler, false),
        COALESCE(engagement.engaged_seconds, 0),
        1,
        1
      FROM active_sessions
      CROSS JOIN LATERAL (
        SELECT
          MIN(bpe.created_at) AS first_pageview_at,
          COUNT(*) AS pageview_count,
          bool_or(bpe.user_id IS NOT NULL) AS logged_in,
          bool_or(#{CrawlerScorer.likely_crawler_condition(table: "bpe")}) AS likely_crawler
        FROM browser_pageview_events bpe
        WHERE bpe.session_id = active_sessions.session_id
      ) stats
      LEFT JOIN browser_pageview_session_engagements engagement
        ON engagement.session_id = active_sessions.session_id
      ON CONFLICT (session_id) DO NOTHING
    SQL
  end
  private_class_method :seed_recent!

  def self.refresh_dirty!
    loop do
      refreshed =
        transaction do
          rows = DB.query(<<~SQL, batch_size: BATCH_SIZE)
              SELECT session_id, first_pageview_at
              FROM browser_pageview_session_rollup_summaries
              WHERE dirty_generation > refreshed_generation
              ORDER BY session_id
              FOR UPDATE SKIP LOCKED
              LIMIT :batch_size
            SQL
          next 0 if rows.empty?

          session_ids = rows.map(&:session_id)
          replace_summaries!(session_ids:)
          record_repair_dates!(rows:, session_ids:)
          session_ids.length
        end
      break if refreshed.zero?
    end
  end
  private_class_method :refresh_dirty!

  def self.replace_summaries!(session_ids:)
    DB.exec(<<~SQL, session_ids:)
        WITH event_stats AS (
          SELECT
            bpe.session_id,
            MIN(bpe.created_at) AS first_pageview_at,
            COUNT(*) AS pageview_count,
            bool_or(bpe.user_id IS NOT NULL) AS logged_in,
            bool_or(#{CrawlerScorer.likely_crawler_condition(table: "bpe")}) AS likely_crawler
          FROM browser_pageview_events bpe
          WHERE bpe.session_id IN (:session_ids)
          GROUP BY bpe.session_id
        ),
        stats AS (
          SELECT
            ids.session_id,
            event_stats.first_pageview_at,
            COALESCE(event_stats.pageview_count, 0) AS pageview_count,
            COALESCE(event_stats.logged_in, false) AS logged_in,
            COALESCE(event_stats.likely_crawler, false) AS likely_crawler,
            COALESCE(engagement.engaged_seconds, 0) AS engaged_seconds
          FROM unnest(ARRAY[:session_ids]::varchar[]) AS ids(session_id)
          LEFT JOIN event_stats ON event_stats.session_id = ids.session_id
          LEFT JOIN browser_pageview_session_engagements engagement
            ON engagement.session_id = ids.session_id
        )
        UPDATE browser_pageview_session_rollup_summaries summary
        SET first_pageview_at = stats.first_pageview_at,
            pageview_count = stats.pageview_count,
            logged_in = stats.logged_in,
            likely_crawler = stats.likely_crawler,
            engaged_seconds = stats.engaged_seconds,
            refreshed_generation = summary.dirty_generation
        FROM stats
        WHERE summary.session_id = stats.session_id
      SQL
  end
  private_class_method :replace_summaries!

  def self.record_repair_dates!(rows:, session_ids:)
    old_dates_by_session = rows.to_h { |row| [row.session_id, row.first_pageview_at&.to_date] }
    dates =
      DB
        .query(<<~SQL, session_ids:)
        SELECT session_id, first_pageview_at
        FROM browser_pageview_session_rollup_summaries
        WHERE session_id IN (:session_ids)
      SQL
        .flat_map do |row|
          old_date = old_dates_by_session[row.session_id]
          old_date ? [old_date, row.first_pageview_at&.to_date] : []
        end

    dates.compact.uniq.each { |date| DB.exec(<<~SQL, date:) }
        INSERT INTO browser_pageview_session_rollup_repair_dates (date)
        VALUES (:date)
        ON CONFLICT (date) DO NOTHING
      SQL
  end
  private_class_method :record_repair_dates!

  def self.repair_older_dates!(start_date:)
    DB
      .query(<<~SQL, start_date:)
      SELECT date
      FROM browser_pageview_session_rollup_repair_dates
      WHERE date < :start_date
      ORDER BY date
    SQL
      .each do |row|
        date = row.date
        if date >= BrowserPageviewEvent.retention_cutoff.to_date + 1
          BrowserPageviewSessionEngagementDailyRollup.aggregate(start_date: date, end_date: date)
          DB.exec(<<~SQL, date:)
            DELETE FROM browser_pageview_session_engagement_daily_rollups
            WHERE date = :date
              AND NOT EXISTS (
                SELECT 1
                FROM browser_pageview_events
                WHERE created_at >= :date AND created_at < :date::date + 1
              )
          SQL
        end
        DB.exec(<<~SQL, date:)
        DELETE FROM browser_pageview_session_rollup_repair_dates WHERE date = :date
      SQL
      end
  end
  private_class_method :repair_older_dates!

  def self.rebuild_recent!(start_date:, end_date:)
    DB.exec(<<~SQL, start_date:, end_date: end_date + 1)
      DELETE FROM browser_pageview_session_engagement_daily_rollups
      WHERE date >= :start_date AND date < :end_date
    SQL

    DB.exec(
      <<~SQL,
        INSERT INTO browser_pageview_session_engagement_daily_rollups
        (
          date, logged_in, sessions, bounced, engaged_seconds_total,
          likely_crawler_sessions, likely_crawler_bounced, likely_crawler_engaged_seconds_total
        )
      SELECT
        first_pageview_at::date,
        logged_in,
        COUNT(*),
        COUNT(*) FILTER (
          WHERE pageview_count = 1 AND engaged_seconds < :bounce_threshold
        ),
        COALESCE(SUM(engaged_seconds), 0),
        COUNT(*) FILTER (WHERE likely_crawler),
        COUNT(*) FILTER (
          WHERE likely_crawler AND pageview_count = 1 AND engaged_seconds < :bounce_threshold
        ),
        COALESCE(SUM(engaged_seconds) FILTER (WHERE likely_crawler), 0)
      FROM browser_pageview_session_rollup_summaries
      WHERE first_pageview_at >= :start_date
        AND first_pageview_at < LEAST(:end_date::timestamp, :session_started_before::timestamp)
        GROUP BY first_pageview_at::date, logged_in
      SQL
      start_date:,
      end_date: end_date + 1,
      session_started_before: BrowserPageviewSessionEngagement::BEACON_SETTLE_PERIOD.ago,
      bounce_threshold:
        BrowserPageviewSessionEngagementDailyRollup.bounce_engaged_seconds_threshold,
    )

    DB.exec(<<~SQL, start_date:, end_date: end_date + 1)
      DELETE FROM browser_pageview_session_rollup_repair_dates
      WHERE date >= :start_date AND date < :end_date
    SQL
  end
  private_class_method :rebuild_recent!

  def self.expire_clean!(start_date:)
    DB.exec(<<~SQL, cutoff: start_date - 2)
      DELETE FROM browser_pageview_session_rollup_summaries
      WHERE refreshed_generation = dirty_generation
        AND (first_pageview_at < :cutoff OR first_pageview_at IS NULL)
    SQL
  end
  private_class_method :expire_clean!

  def self.lock_daily_rollups!
    DB.exec("SELECT pg_advisory_xact_lock(130712, 1)")
  end
end

# == Schema Information
#
# Table name: browser_pageview_session_rollup_summaries
#
#  dirty_generation     :bigint           default(1), not null
#  engaged_seconds      :bigint           default(0), not null
#  first_pageview_at    :datetime
#  likely_crawler       :boolean          default(FALSE), not null
#  logged_in            :boolean          default(FALSE), not null
#  pageview_count       :bigint           default(0), not null
#  refreshed_generation :bigint           default(0), not null
#  session_id           :string(32)       not null, primary key
#
# Indexes
#
#  idx_on_first_pageview_at_b3b9b0191c  (first_pageview_at)
#
