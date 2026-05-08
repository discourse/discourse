# frozen_string_literal: true

class PageviewDailyAggregate < ActiveRecord::Base
  self.primary_key = nil

  DIRECT_SOURCE_NAME = "Direct"
  OTHER_SOURCE_NAME = "(Other)"
  SOURCE_TABLE_NAME = "browser_pageview_events"

  class << self
    def rollup!(date)
      date = date.to_date
      day_start = Time.utc(date.year, date.month, date.day)
      day_end = day_start + 1.day

      transaction do
        DB.exec("DELETE FROM #{table_name} WHERE date = :date", date: date)

        DB.exec(
          <<~SQL,
            INSERT INTO #{table_name} (date, country_code, source_name, is_logged_in, count)
            WITH parsed_events AS (
              SELECT
                (created_at AT TIME ZONE 'UTC')::date AS date,
                country_code,
                user_id IS NOT NULL AS is_logged_in,
                CASE
                  WHEN referrer IS NULL OR btrim(referrer) = '' THEN :direct_source_name
                  ELSE COALESCE(
                    NULLIF(
                      regexp_replace(
                        substring(lower(referrer) FROM '^[a-z][a-z0-9+.-]*://([^/?#:]+)'),
                        '^www\\.',
                        ''
                      ),
                      ''
                    ),
                    :other_source_name
                  )
                END AS source_host,
                substring(lower(referrer) FROM '^[a-z][a-z0-9+.-]*://[^/?#:]+(/r/[^/?#]+)') AS reddit_path
              FROM #{source_table_name}
              WHERE created_at >= :day_start AND created_at < :day_end
            )
            SELECT
              date,
              country_code,
              LEFT(
                CASE
                  WHEN source_host IN ('reddit.com', 'old.reddit.com', 'new.reddit.com', 'np.reddit.com') AND reddit_path IS NOT NULL
                    THEN 'reddit.com' || reddit_path
                  WHEN source_host IN ('old.reddit.com', 'new.reddit.com', 'np.reddit.com')
                    THEN 'reddit.com'
                  ELSE source_host
                END,
                100
              ) AS source_name,
              is_logged_in,
              COUNT(*) AS count
            FROM parsed_events
            GROUP BY 1, 2, 3, 4
          SQL
          day_start: day_start,
          day_end: day_end,
          direct_source_name: DIRECT_SOURCE_NAME,
          other_source_name: OTHER_SOURCE_NAME,
        )
      end
    end

    private

    def source_table_name
      self::SOURCE_TABLE_NAME
    end
  end
end

# == Schema Information
#
# Table name: pageview_daily_aggregates
#
#  count        :integer          not null
#  country_code :string(2)
#  date         :date             not null
#  is_logged_in :boolean          not null
#  source_name  :string(100)      not null
#
# Indexes
#
#  pageview_daily_aggregates_with_country_idx     (date,country_code,source_name,is_logged_in) UNIQUE WHERE (country_code IS NOT NULL)
#  pageview_daily_aggregates_without_country_idx  (date,source_name,is_logged_in) UNIQUE WHERE (country_code IS NULL)
#
