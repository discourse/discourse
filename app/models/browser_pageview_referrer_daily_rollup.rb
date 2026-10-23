# frozen_string_literal: true

class BrowserPageviewReferrerDailyRollup < ActiveRecord::Base
  def self.aggregate(start_date:, end_date:)
    start_date = start_date.to_date
    end_date = end_date.to_date + 1

    DB.exec(<<~SQL, start_date:, end_date:)
      INSERT INTO browser_pageview_referrer_daily_rollups (
        date, normalized_referrer, count, logged_in_count, likely_crawler_count, likely_crawler_logged_in_count
      )
      SELECT
        created_at::date AS date,
        normalized_referrer,
        COUNT(*) AS count,
        COUNT(*) FILTER (WHERE user_id IS NOT NULL) AS logged_in_count,
        COUNT(*) FILTER (WHERE #{CrawlerScorer.likely_crawler_condition}) AS likely_crawler_count,
        COUNT(*) FILTER (
          WHERE user_id IS NOT NULL AND #{CrawlerScorer.likely_crawler_condition}
        ) AS likely_crawler_logged_in_count
      FROM browser_pageview_events
      WHERE created_at >= :start_date
        AND created_at < :end_date
      GROUP BY date, normalized_referrer
      ON CONFLICT (date, normalized_referrer) DO UPDATE
      SET count = EXCLUDED.count,
          logged_in_count = EXCLUDED.logged_in_count,
          likely_crawler_count = EXCLUDED.likely_crawler_count,
          likely_crawler_logged_in_count = EXCLUDED.likely_crawler_logged_in_count
    SQL
  end

  def self.recompute(dates)
    dates = Array(dates).map(&:to_date).uniq
    return if dates.empty?

    # The rollups are the permanent record, but their source events are pruned
    # after a retention period (CleanUpBrowserPageviewEvents). Only rebuild
    # dates that still have events so we never delete a rollup we can no longer
    # reconstruct from events.
    dates = DB.query_single(<<~SQL, dates:)
      SELECT d.date
      FROM unnest(ARRAY[:dates]::date[]) AS d(date)
      WHERE EXISTS (
        SELECT 1
        FROM browser_pageview_events e
        WHERE e.created_at >= d.date
          AND e.created_at < d.date + 1
      )
    SQL
    return if dates.empty?

    transaction do
      DB.exec(<<~SQL, dates: dates)
        DELETE FROM browser_pageview_referrer_daily_rollups
        WHERE date IN (:dates)
      SQL

      dates.each { |date| aggregate(start_date: date, end_date: date) }
    end
  end
end

# == Schema Information
#
# Table name: browser_pageview_referrer_daily_rollups
#
#  id                             :bigint           not null, primary key
#  count                          :bigint           not null
#  date                           :date             not null
#  likely_crawler_count           :bigint           default(0), not null
#  likely_crawler_logged_in_count :bigint           default(0), not null
#  logged_in_count                :bigint           not null
#  normalized_referrer            :string(2000)
#
# Indexes
#
#  idx_bprd_rollups_date_referrer_unique  (date,normalized_referrer) UNIQUE NULLS NOT DISTINCT
#
