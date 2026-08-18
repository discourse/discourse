# frozen_string_literal: true

class BrowserPageviewEntryUrlDailyRollupDate < ActiveRecord::Base
end

# == Schema Information
#
# Table name: browser_pageview_entry_url_daily_rollup_dates
#
#  id   :bigint           not null, primary key
#  date :date             not null
#
# Indexes
#
#  idx_bpeu_daily_rollup_dates_unique  (date) UNIQUE
#
