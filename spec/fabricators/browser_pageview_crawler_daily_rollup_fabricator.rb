# frozen_string_literal: true

Fabricator(:browser_pageview_crawler_daily_rollup) do
  date { Date.current }
  logged_in false
  count 1
end
