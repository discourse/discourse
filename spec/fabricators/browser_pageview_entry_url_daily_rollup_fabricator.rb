# frozen_string_literal: true

Fabricator(:browser_pageview_entry_url_daily_rollup) do
  date { Time.zone.today }
  entry_url "/latest"
  count 1
  logged_in_count 0
  likely_crawler_count 0
  likely_crawler_logged_in_count 0
end
