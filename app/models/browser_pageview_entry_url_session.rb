# frozen_string_literal: true

class BrowserPageviewEntryUrlSession < ActiveRecord::Base
  SAFE_ENTRY_ROUTE_PATTERN =
    %r{/(?:t|c|tag|tags|g)(?:/.*)?|/(?:latest|top|new|categories|faq|guidelines|about|groups|badges)}
  private_constant :SAFE_ENTRY_ROUTE_PATTERN

  def self.refresh(start_date:, end_date:)
    start_date = start_date.to_date
    end_date = end_date.to_date + 1
    source_condition = BrowserPageviewEvent.rollup_source_condition(table: "e")

    old_dates = affected_dates(start_date:, end_date:)

    DB.exec(
      <<~SQL,
        WITH active_sessions AS (
          SELECT DISTINCT e.session_id
          FROM browser_pageview_events e
          WHERE e.created_at >= :start_date
            AND e.created_at < :end_date
            AND #{source_condition}
        ),
        session_events AS (
          SELECT DISTINCT ON (e.session_id)
            e.session_id,
            e.id AS first_event_id,
            e.created_at AS first_seen_at,
            MAX(e.created_at) OVER (PARTITION BY e.session_id) AS last_seen_at,
            CASE
              WHEN e.normalized_url ~ :safe_entry_url_pattern THEN e.normalized_url
              ELSE NULL
            END AS entry_url,
            e.user_id IS NOT NULL AS logged_in,
            COALESCE(#{CrawlerScorer.likely_crawler_condition(table: "e")}, false) AS likely_crawler
          FROM browser_pageview_events e
          JOIN active_sessions ON active_sessions.session_id = e.session_id
          WHERE #{source_condition}
          ORDER BY e.session_id, e.created_at, e.id
        )
        INSERT INTO browser_pageview_entry_url_sessions (
          session_id,
          first_event_id,
          first_seen_at,
          last_seen_at,
          entry_url,
          logged_in,
          likely_crawler,
          created_at,
          updated_at
        )
        SELECT
          session_id,
          first_event_id,
          first_seen_at,
          last_seen_at,
          entry_url,
          logged_in,
          likely_crawler,
          :now,
          :now
        FROM session_events
        ON CONFLICT (session_id) DO UPDATE
        SET first_event_id = CASE
              WHEN (EXCLUDED.first_seen_at, EXCLUDED.first_event_id) <=
                   (browser_pageview_entry_url_sessions.first_seen_at,
                    browser_pageview_entry_url_sessions.first_event_id)
              THEN EXCLUDED.first_event_id
              ELSE browser_pageview_entry_url_sessions.first_event_id
            END,
            first_seen_at = LEAST(
              browser_pageview_entry_url_sessions.first_seen_at,
              EXCLUDED.first_seen_at
            ),
            last_seen_at = GREATEST(
              browser_pageview_entry_url_sessions.last_seen_at,
              EXCLUDED.last_seen_at
            ),
            entry_url = CASE
              WHEN (EXCLUDED.first_seen_at, EXCLUDED.first_event_id) <=
                   (browser_pageview_entry_url_sessions.first_seen_at,
                    browser_pageview_entry_url_sessions.first_event_id)
              THEN EXCLUDED.entry_url
              ELSE browser_pageview_entry_url_sessions.entry_url
            END,
            logged_in = CASE
              WHEN (EXCLUDED.first_seen_at, EXCLUDED.first_event_id) <=
                   (browser_pageview_entry_url_sessions.first_seen_at,
                    browser_pageview_entry_url_sessions.first_event_id)
              THEN EXCLUDED.logged_in
              ELSE browser_pageview_entry_url_sessions.logged_in
            END,
            likely_crawler = CASE
              WHEN (EXCLUDED.first_seen_at, EXCLUDED.first_event_id) <=
                   (browser_pageview_entry_url_sessions.first_seen_at,
                    browser_pageview_entry_url_sessions.first_event_id)
              THEN EXCLUDED.likely_crawler
              ELSE browser_pageview_entry_url_sessions.likely_crawler
            END,
            updated_at = :now
      SQL
      start_date:,
      end_date:,
      safe_entry_url_pattern: safe_entry_url_pattern,
      now: Time.zone.now,
    )

    (old_dates + affected_dates(start_date:, end_date:)).uniq
  end

  def self.cleanup!
    DB.exec(<<~SQL, retention_cutoff: BrowserPageviewEvent.retention_cutoff)
      DELETE FROM browser_pageview_entry_url_sessions sessions
      WHERE sessions.last_seen_at < :retention_cutoff
        AND NOT EXISTS (
          SELECT 1
          FROM browser_pageview_events events
          WHERE events.session_id = sessions.session_id
            AND #{BrowserPageviewEvent.rollup_source_condition(table: "events")}
        )
    SQL
  end

  def self.affected_dates(start_date:, end_date:)
    DB.query_single(<<~SQL, start_date:, end_date:)
        SELECT DISTINCT sessions.first_seen_at::date
        FROM browser_pageview_entry_url_sessions sessions
        WHERE sessions.session_id IN (
          SELECT DISTINCT events.session_id
          FROM browser_pageview_events events
          WHERE events.created_at >= :start_date
            AND events.created_at < :end_date
            AND #{BrowserPageviewEvent.rollup_source_condition(table: "events")}
        )
      SQL
  end
  private_class_method :affected_dates

  def self.safe_entry_url_pattern
    base_path = Discourse.base_path
    root_path = base_path.presence || "/"
    "^(?:#{Regexp.escape(root_path)}|#{Regexp.escape(base_path)}(?:#{SAFE_ENTRY_ROUTE_PATTERN.source}))$"
  end
  private_class_method :safe_entry_url_pattern
end

# == Schema Information
#
# Table name: browser_pageview_entry_url_sessions
#
#  id             :bigint           not null, primary key
#  entry_url      :string(2000)
#  first_seen_at  :datetime         not null
#  last_seen_at   :datetime         not null
#  likely_crawler :boolean          default(FALSE), not null
#  logged_in      :boolean          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  first_event_id :bigint           not null
#  session_id     :string(32)       not null
#
# Indexes
#
#  idx_bpeu_sessions_first_seen      (first_seen_at) USING brin
#  idx_bpeu_sessions_last_seen       (last_seen_at) USING brin
#  idx_bpeu_sessions_session_unique  (session_id) UNIQUE
#
