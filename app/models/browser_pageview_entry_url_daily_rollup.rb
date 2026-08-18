# frozen_string_literal: true

class BrowserPageviewEntryUrlDailyRollup < ActiveRecord::Base
  SAFE_ENTRY_ROUTE_PATTERN =
    %r{/(?:t)(?:/.*)?|/(?:latest|top|new|categories|faq|guidelines|about|groups|badges|tags)}
  TOPIC_ENTRY_ROUTE_PATTERN = %r{/t(?:/.*)?}
  private_constant :SAFE_ENTRY_ROUTE_PATTERN
  private_constant :TOPIC_ENTRY_ROUTE_PATTERN

  def self.aggregate(start_date:, end_date:)
    start_date = [start_date.to_date, BrowserPageviewEvent.retention_cutoff.to_date].max
    start_date = rebuildable_start_date(start_date)
    end_date = end_date.to_date
    return if start_date > end_date

    exclusive_end_date = end_date + 1
    source_condition =
      BrowserPageviewEvent.rollup_source_condition(
        table: "events",
        start_date:,
        end_date: exclusive_end_date,
      )
    entry_url_sql = <<~SQL.squish
      CASE
        WHEN events.normalized_url ~ :topic_entry_url_pattern
        THEN CONCAT(:base_path, '/t/', entry_topics.slug, '/', entry_topics.id)
        ELSE events.normalized_url
      END
    SQL

    transaction do
      DB.exec(<<~SQL, start_date:, end_date: exclusive_end_date)
        DELETE FROM browser_pageview_entry_url_daily_rollups rollup
        WHERE rollup.date >= :start_date
          AND rollup.date < :end_date
          AND rollup.entry_url IS NOT NULL
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
          INSERT INTO browser_pageview_entry_url_daily_rollups (
            date,
            entry_url,
            count,
            logged_in_count,
            likely_crawler_count,
            likely_crawler_logged_in_count
          )
          SELECT
            events.created_at::date,
            #{entry_url_sql},
            COUNT(*),
            COUNT(*) FILTER (WHERE events.user_id IS NOT NULL),
            COUNT(*) FILTER (
              WHERE COALESCE(#{CrawlerScorer.likely_crawler_condition(table: "events")}, false)
            ),
            COUNT(*) FILTER (
              WHERE events.user_id IS NOT NULL
                AND COALESCE(#{CrawlerScorer.likely_crawler_condition(table: "events")}, false)
            )
          FROM browser_pageview_events events
          LEFT JOIN topics entry_topics ON entry_topics.id = events.topic_id
          LEFT JOIN categories entry_categories ON entry_categories.id = entry_topics.category_id
          WHERE events.created_at >= :start_date
            AND events.created_at < :end_date
            AND #{source_condition}
            AND events.normalized_url ~ :safe_entry_url_pattern
            AND (
              events.normalized_url !~ :topic_entry_url_pattern
              OR (
                entry_topics.archetype <> :private_message_archetype
                AND entry_topics.deleted_at IS NULL
                AND entry_topics.visible
                AND (
                  entry_topics.category_id IS NULL
                  OR NOT entry_categories.read_restricted
                )
              )
            )
            AND (
              NULLIF(events.referrer, '') IS NULL
              OR (
                events.normalized_referrer IS NOT NULL
                AND split_part(split_part(events.normalized_referrer, '/', 1), '?', 1)
                  NOT IN (:site_hostnames)
              )
            )
          GROUP BY events.created_at::date, #{entry_url_sql}
        SQL
        start_date:,
        end_date: exclusive_end_date,
        safe_entry_url_pattern: safe_entry_url_pattern,
        topic_entry_url_pattern: topic_entry_url_pattern,
        base_path: Discourse.base_path,
        private_message_archetype: Archetype.private_message,
        site_hostnames:,
      )
    end
  end

  def self.recompute(dates)
    Array(dates).map(&:to_date).uniq.each { |date| aggregate(start_date: date, end_date: date) }
  end

  def self.last_full_rebuild_date
    where(entry_url: nil).maximum(:date)
  end

  def self.mark_full_rebuild(date:)
    transaction do
      where(entry_url: nil).delete_all
      create!(
        date: date.to_date,
        entry_url: nil,
        count: 0,
        logged_in_count: 0,
        likely_crawler_count: 0,
        likely_crawler_logged_in_count: 0,
      )
    end
  end

  def self.rebuildable_start_date(start_date)
    earliest_source_date =
      BrowserPageviewEvent
        .where("created_at >= ?", BrowserPageviewEvent.retention_cutoff)
        .where(BrowserPageviewEvent.rollup_source_condition)
        .minimum(:created_at)
        &.to_date
    return start_date if earliest_source_date.nil? || start_date > earliest_source_date

    has_older_rollups = where.not(entry_url: nil).where("date < ?", earliest_source_date).exists?
    has_older_rollups ? earliest_source_date + 1 : start_date
  end
  private_class_method :rebuildable_start_date

  def self.safe_entry_url_pattern
    base_path = Discourse.base_path
    root_path = base_path.presence || "/"
    "^(?:#{Regexp.escape(root_path)}|#{Regexp.escape(base_path)}(?:#{SAFE_ENTRY_ROUTE_PATTERN.source}))$"
  end
  private_class_method :safe_entry_url_pattern

  def self.topic_entry_url_pattern
    "^#{Regexp.escape(Discourse.base_path)}#{TOPIC_ENTRY_ROUTE_PATTERN.source}$"
  end
  private_class_method :topic_entry_url_pattern

  def self.site_hostnames
    hostnames =
      RailsMultisite::ConnectionManagement.current_db_hostnames + [Discourse.current_hostname]
    hostnames
      .filter_map { |hostname| BrowserPageviewEventUrlNormalizer.normalize_host(hostname) }
      .uniq
  end
  private_class_method :site_hostnames
end

# == Schema Information
#
# Table name: browser_pageview_entry_url_daily_rollups
#
#  id                             :bigint           not null, primary key
#  count                          :bigint           not null
#  date                           :date             not null
#  entry_url                      :string(2000)
#  likely_crawler_count           :bigint           default(0), not null
#  likely_crawler_logged_in_count :bigint           default(0), not null
#  logged_in_count                :bigint           not null
#
# Indexes
#
#  idx_bpeu_daily_rollups_date_url_unique  (date,entry_url) UNIQUE NULLS NOT DISTINCT
#
