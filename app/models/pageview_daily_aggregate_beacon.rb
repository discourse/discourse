# frozen_string_literal: true

class PageviewDailyAggregateBeacon < PageviewDailyAggregate
  self.table_name = "pageview_daily_aggregates_beacon"

  SOURCE_TABLE_NAME = "browser_pageview_events_beacon"
end

# == Schema Information
#
# Table name: pageview_daily_aggregates_beacon
#
#  count        :integer          not null
#  country_code :string(2)
#  date         :date             not null
#  is_logged_in :boolean          not null
#  source_name  :string(100)      not null
#
# Indexes
#
#  pageview_daily_aggregates_beacon_with_country_idx     (date,country_code,source_name,is_logged_in) UNIQUE WHERE (country_code IS NOT NULL)
#  pageview_daily_aggregates_beacon_without_country_idx  (date,source_name,is_logged_in) UNIQUE WHERE (country_code IS NULL)
#
