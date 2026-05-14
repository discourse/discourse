# frozen_string_literal: true

class BrowserPageviewDailyAggregate < ActiveRecord::Base
  self.primary_key = nil

  DIRECT_SOURCE_NAME = "Direct"
  INTERNAL_SOURCE_NAME = "(Internal)"
  OTHER_SOURCE_NAME = "(Other)"
end

# == Schema Information
#
# Table name: browser_pageview_daily_aggregates
#
#  count        :integer          not null
#  country_code :string(2)
#  date         :date             not null
#  is_logged_in :boolean          not null
#  source_name  :string(100)      not null
#
# Indexes
#
#  browser_pageview_daily_aggregates_with_country_idx     (date,country_code,source_name,is_logged_in) UNIQUE WHERE (country_code IS NOT NULL)
#  browser_pageview_daily_aggregates_without_country_idx  (date,source_name,is_logged_in) UNIQUE WHERE (country_code IS NULL)
#
