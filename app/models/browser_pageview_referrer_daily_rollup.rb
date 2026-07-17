# frozen_string_literal: true

class BrowserPageviewReferrerDailyRollup < ActiveRecord::Base
  def self.aggregate(
    start_date:,
    end_date:,
    source: BrowserPageviewEvent.rollup_source_for(start_date)
  )
    start_date = start_date.to_date
    end_date = end_date.to_date + 1

    DB.exec(<<~SQL, start_date:, end_date:, source:)
      INSERT INTO browser_pageview_referrer_daily_rollups (date, normalized_referrer, count, logged_in_count)
      SELECT
        created_at::date AS date,
        normalized_referrer,
        COUNT(*) AS count,
        COUNT(*) FILTER (WHERE user_id IS NOT NULL) AS logged_in_count
      FROM browser_pageview_events
      WHERE created_at >= :start_date
        AND created_at < :end_date
        AND source = :source
      GROUP BY date, normalized_referrer
      ON CONFLICT (date, normalized_referrer) DO UPDATE
      SET count = EXCLUDED.count,
          logged_in_count = EXCLUDED.logged_in_count
    SQL
  end

  def self.recompute(dates)
    dates = Array(dates).map(&:to_date).uniq
    return if dates.empty?

    sources = dates.map { |date| BrowserPageviewEvent.rollup_source_for(date) }

    # The rollups are the permanent record, but their source events are pruned
    # after a retention period (CleanUpBrowserPageviewEvents). Only rebuild
    # dates that still have events so we never delete a rollup we can no longer
    # reconstruct from events.
    rebuildable = DB.query(<<~SQL, dates:, sources:)
      SELECT d.date, d.source
      FROM unnest(ARRAY[:dates]::date[], ARRAY[:sources]::int[]) AS d(date, source)
      WHERE EXISTS (
        SELECT 1
        FROM browser_pageview_events e
        WHERE e.created_at >= d.date
          AND e.created_at < d.date + 1
          AND e.source = d.source
      )
    SQL
    return if rebuildable.empty?

    transaction do
      DB.exec(<<~SQL, dates: rebuildable.map(&:date))
        DELETE FROM browser_pageview_referrer_daily_rollups
        WHERE date IN (:dates)
      SQL

      rebuildable.each do |row|
        aggregate(start_date: row.date, end_date: row.date, source: row.source)
      end
    end
  end
end

# == Schema Information
#
# Table name: browser_pageview_referrer_daily_rollups
#
#  id                  :bigint           not null, primary key
#  count               :bigint           not null
#  date                :date             not null
#  logged_in_count     :bigint           not null
#  normalized_referrer :string(2000)
#
# Indexes
#
#  idx_bprd_rollups_date_referrer_unique  (date,normalized_referrer) UNIQUE NULLS NOT DISTINCT
#
