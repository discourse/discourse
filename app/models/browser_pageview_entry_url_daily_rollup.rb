# frozen_string_literal: true

class BrowserPageviewEntryUrlDailyRollup < ActiveRecord::Base
  def self.aggregate(start_date:, end_date:)
    start_date = start_date.to_date
    end_date = end_date.to_date

    transaction do
      affected_dates =
        BrowserPageviewEntryUrlSession.refresh(start_date: start_date, end_date: end_date)
      rebuild_dates((start_date..end_date).to_a | affected_dates)
      record_coverage(start_date:, end_date:)
    end
  end

  def self.rebuild_dates(dates)
    dates = rebuildable_dates(dates)
    return if dates.empty?

    DB.exec(<<~SQL, dates:)
      DELETE FROM browser_pageview_entry_url_daily_rollups
      WHERE date IN (:dates)
    SQL

    DB.exec(<<~SQL, dates:)
      INSERT INTO browser_pageview_entry_url_daily_rollups (
        date,
        entry_url,
        count,
        logged_in_count,
        likely_crawler_count,
        likely_crawler_logged_in_count
      )
      SELECT
        first_seen_at::date AS date,
        entry_url,
        COUNT(*) AS count,
        COUNT(*) FILTER (WHERE logged_in) AS logged_in_count,
        COUNT(*) FILTER (WHERE likely_crawler) AS likely_crawler_count,
        COUNT(*) FILTER (WHERE logged_in AND likely_crawler) AS likely_crawler_logged_in_count
      FROM browser_pageview_entry_url_sessions
      WHERE first_seen_at::date IN (:dates)
        AND entry_url IS NOT NULL
      GROUP BY first_seen_at::date, entry_url
    SQL
  end

  def self.rebuildable_dates(dates)
    dates = Array(dates).map(&:to_date).uniq
    return dates if !SiteSetting.clean_up_browser_pageview_events

    dates.select { |date| date >= BrowserPageviewEvent.retention_cutoff.to_date }
  end
  private_class_method :rebuildable_dates

  def self.record_coverage(start_date:, end_date:)
    DB.exec(<<~SQL, start_date:, end_date:)
      INSERT INTO browser_pageview_entry_url_daily_rollup_dates (date)
      SELECT generate_series(:start_date::date, :end_date::date, INTERVAL '1 day')::date
      ON CONFLICT (date) DO NOTHING
    SQL
  end
  private_class_method :record_coverage
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
