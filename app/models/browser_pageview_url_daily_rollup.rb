# frozen_string_literal: true

class BrowserPageviewUrlDailyRollup < ActiveRecord::Base
  def self.aggregate(start_date:, end_date:, source: BrowserPageviewEvent.rollup_source)
    start_date = start_date.to_date
    end_date = end_date.to_date + 1

    DB.exec(<<~SQL, start_date:, end_date:, source:)
      INSERT INTO browser_pageview_url_daily_rollups (date, normalized_url, count, logged_in_count)
      SELECT
        created_at::date AS date,
        normalized_url,
        COUNT(*) AS count,
        COUNT(*) FILTER (WHERE user_id IS NOT NULL) AS logged_in_count
      FROM browser_pageview_events
      WHERE created_at >= :start_date
        AND created_at < :end_date
        AND source = :source
      GROUP BY date, normalized_url
      ON CONFLICT (date, normalized_url) DO UPDATE
      SET count = EXCLUDED.count,
          logged_in_count = EXCLUDED.logged_in_count
    SQL
  end
end

# == Schema Information
#
# Table name: browser_pageview_url_daily_rollups
#
#  id              :bigint           not null, primary key
#  count           :bigint           not null
#  date            :date             not null
#  logged_in_count :bigint           not null
#  normalized_url  :string(2000)
#
# Indexes
#
#  idx_bpud_rollups_date_url_unique  (date,normalized_url) UNIQUE NULLS NOT DISTINCT
#
