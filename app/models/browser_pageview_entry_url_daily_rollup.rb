# frozen_string_literal: true

class BrowserPageviewEntryUrlDailyRollup < ActiveRecord::Base
  SAFE_ENTRY_ROUTE_PATTERN =
    %r{/(?:t|c|tag|tags|g)(?:/.*)?|/(?:latest|top|new|categories|faq|guidelines|about|groups|badges)}
  private_constant :SAFE_ENTRY_ROUTE_PATTERN

  def self.aggregate(start_date:, end_date:)
    attributes = { start_date: start_date.to_date, end_date: end_date.to_date }

    if connection.transaction_open?
      aggregate_in_transaction(**attributes)
    else
      transaction(isolation: :repeatable_read) { aggregate_in_transaction(**attributes) }
    end
  end

  def self.aggregate_in_transaction(start_date:, end_date:)
    processing_start_date = [start_date, BrowserPageviewEvent.retention_cutoff.to_date].max
    start_date = rebuildable_start_date(processing_start_date)
    source_condition = BrowserPageviewEvent.rollup_source_condition(table: "events")

    if start_date <= end_date
      exclusive_end_date = end_date + 1
      DB.exec(<<~SQL, start_date:, end_date: exclusive_end_date)
        DELETE FROM browser_pageview_entry_url_daily_rollups rollup
        WHERE rollup.date >= :start_date
          AND rollup.date < :end_date
          AND EXISTS (
            SELECT 1
            FROM browser_pageview_events events
            WHERE events.created_at >= rollup.date
              AND events.created_at < rollup.date + 1
              AND #{source_condition}
          )
      SQL

      DB.exec(
        <<~SQL,
          WITH active_sessions AS (
            SELECT DISTINCT events.session_id
            FROM browser_pageview_events events
            WHERE events.created_at >= :start_date
              AND events.created_at < LEAST(:end_date::timestamp, :session_started_before::timestamp)
              AND #{source_condition}
          ),
          session_entries AS (
            SELECT DISTINCT ON (events.session_id)
              events.created_at AS first_seen_at,
              CASE
                WHEN events.normalized_url ~ :safe_entry_url_pattern THEN events.normalized_url
                ELSE NULL
              END AS entry_url,
              events.user_id IS NOT NULL AS logged_in,
              COALESCE(#{CrawlerScorer.likely_crawler_condition(table: "events")}, false) AS likely_crawler
            FROM browser_pageview_events events
            JOIN active_sessions ON active_sessions.session_id = events.session_id
            WHERE #{source_condition}
            ORDER BY events.session_id, events.created_at, events.id
          )
          INSERT INTO browser_pageview_entry_url_daily_rollups (
            date,
            entry_url,
            count,
            logged_in_count,
            likely_crawler_count,
            likely_crawler_logged_in_count
          )
          SELECT
            first_seen_at::date,
            entry_url,
            COUNT(*),
            COUNT(*) FILTER (WHERE logged_in),
            COUNT(*) FILTER (WHERE likely_crawler),
            COUNT(*) FILTER (WHERE logged_in AND likely_crawler)
          FROM session_entries
          WHERE first_seen_at >= :start_date
            AND first_seen_at < :end_date
            AND entry_url IS NOT NULL
          GROUP BY first_seen_at::date, entry_url
        SQL
        start_date:,
        end_date: exclusive_end_date,
        session_started_before: BrowserPageviewSessionEngagement::BEACON_SETTLE_PERIOD.ago,
        safe_entry_url_pattern: safe_entry_url_pattern,
      )
    end

    DB.exec(
      <<~SQL,
        UPDATE browser_pageview_events events
        SET entry_url_rollup_version = :version
        WHERE events.created_at >= :start_date
          AND events.created_at < :end_date
          AND #{source_condition}
          AND (
            events.entry_url_rollup_version IS NULL
            OR events.entry_url_rollup_version < :version
          )
      SQL
      start_date: processing_start_date,
      end_date: end_date + 1,
      version: BrowserPageviewEventUrlNormalizer::SITE_PATH_VERSION,
    )
  end
  private_class_method :aggregate_in_transaction

  def self.rebuildable_start_date(start_date)
    earliest_source_date =
      BrowserPageviewEvent
        .where("created_at >= ?", BrowserPageviewEvent.retention_cutoff)
        .where(BrowserPageviewEvent.rollup_source_condition)
        .minimum(:created_at)
        &.to_date
    return start_date if earliest_source_date.nil? || start_date > earliest_source_date

    has_older_rollups = where("date < ?", earliest_source_date).exists?
    has_older_rollups ? earliest_source_date + 1 : start_date
  end
  private_class_method :rebuildable_start_date

  def self.safe_entry_url_pattern
    base_path = Discourse.base_path
    root_path = base_path.presence || "/"
    "^(?:#{Regexp.escape(root_path)}|#{Regexp.escape(base_path)}(?:#{SAFE_ENTRY_ROUTE_PATTERN.source}))$"
  end
  private_class_method :safe_entry_url_pattern
end

# == Schema Information
#
# Table name: browser_pageview_entry_url_daily_rollups
#
#  id                             :bigint           not null, primary key
#  count                          :bigint           not null
#  date                           :date             not null
#  entry_url                      :string(2000)     not null
#  likely_crawler_count           :bigint           default(0), not null
#  likely_crawler_logged_in_count :bigint           default(0), not null
#  logged_in_count                :bigint           not null
#
# Indexes
#
#  idx_bpeu_daily_rollups_date_url_unique  (date,entry_url) UNIQUE
#
