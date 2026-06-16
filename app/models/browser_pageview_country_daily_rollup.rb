# frozen_string_literal: true

class BrowserPageviewCountryDailyRollup < ActiveRecord::Base
  def self.aggregate(start_date:, end_date:, source: BrowserPageviewEvent.rollup_source)
    start_date = start_date.to_date
    end_date = end_date.to_date + 1

    DB.exec(<<~SQL, start_date:, end_date:, source:)
      INSERT INTO browser_pageview_country_daily_rollups (date, country_code, count, logged_in_count)
      SELECT
        created_at::date AS date,
        country_code,
        COUNT(*) AS count,
        COUNT(*) FILTER (WHERE user_id IS NOT NULL) AS logged_in_count
      FROM browser_pageview_events
      WHERE created_at >= :start_date
        AND created_at < :end_date
        AND source = :source
      GROUP BY date, country_code
      ON CONFLICT (date, country_code) DO UPDATE
      SET count = EXCLUDED.count,
          logged_in_count = EXCLUDED.logged_in_count
    SQL
  end
end

# == Schema Information
#
# Table name: browser_pageview_country_daily_rollups
#
#  id              :bigint           not null, primary key
#  count           :bigint           not null
#  country_code    :string(2)
#  date            :date             not null
#  logged_in_count :bigint           not null
#
# Indexes
#
#  idx_bpcd_rollups_date_country_unique  (date,country_code) UNIQUE NULLS NOT DISTINCT
#
