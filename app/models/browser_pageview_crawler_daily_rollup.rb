# frozen_string_literal: true

class BrowserPageviewCrawlerDailyRollup < ActiveRecord::Base
  class << self
    def aggregate(start_date:, end_date:)
      start_date = start_date.to_date
      end_date = end_date.to_date + 1

      DB.exec(<<~SQL, start_date:, end_date:, threshold: CrawlerScorer::BOT_SCORE_THRESHOLD)
      INSERT INTO browser_pageview_crawler_daily_rollups (date, logged_in, count)
      SELECT
        created_at::date AS date,
        user_id IS NOT NULL AS logged_in,
        COUNT(*) AS count
      FROM browser_pageview_events
      WHERE created_at >= :start_date
        AND created_at < :end_date
        AND score > :threshold
        AND #{BrowserPageviewEvent.rollup_source_condition}
      GROUP BY date, logged_in
      ON CONFLICT (date, logged_in) DO UPDATE
      SET count = EXCLUDED.count
    SQL
    end
  end
end

# == Schema Information
#
# Table name: browser_pageview_crawler_daily_rollups
#
#  id        :bigint           not null, primary key
#  count     :bigint           not null
#  date      :date             not null
#  logged_in :boolean          not null
#
# Indexes
#
#  idx_bpcrawler_rollups_date_logged_in_unique  (date,logged_in) UNIQUE
#
