# frozen_string_literal: true

class BrowserPageviewEntryUrlDailyRollup < ActiveRecord::Base
  class << self
    def aggregate(start_date:, end_date:)
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
      transaction do
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

        DB.exec(<<~SQL, start_date:, end_date: exclusive_end_date, site_hostnames:)
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
            events.normalized_url,
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
          WHERE events.created_at >= :start_date
            AND events.created_at < :end_date
            AND #{source_condition}
            AND events.normalized_url IS NOT NULL
            AND (
              NULLIF(events.referrer, '') IS NULL
              OR (
                events.normalized_referrer IS NOT NULL
                AND split_part(split_part(events.normalized_referrer, '/', 1), '?', 1)
                  NOT IN (:site_hostnames)
              )
            )
          GROUP BY events.created_at::date, events.normalized_url
        SQL
      end
    end

    def recompute(dates)
      Array(dates).map(&:to_date).uniq.each { |date| aggregate(start_date: date, end_date: date) }
    end

    def site_hostnames
      hostnames =
        RailsMultisite::ConnectionManagement.current_db_hostnames + [Discourse.current_hostname]
      hostnames
        .filter_map { |hostname| BrowserPageviewEventUrlNormalizer.normalize_host(hostname) }
        .uniq
    end

    private

    def rebuildable_start_date(start_date)
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
#  entry_url                      :string(2000)     not null
#  likely_crawler_count           :bigint           default(0), not null
#  likely_crawler_logged_in_count :bigint           default(0), not null
#  logged_in_count                :bigint           not null
#
# Indexes
#
#  idx_bpeu_daily_rollups_date_url_unique  (date,entry_url) UNIQUE
#
