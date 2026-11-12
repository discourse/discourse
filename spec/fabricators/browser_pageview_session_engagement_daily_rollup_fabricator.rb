# frozen_string_literal: true

Fabricator(:browser_pageview_session_engagement_daily_rollup) do
  date { Time.zone.today }
  logged_in false
  sessions 1
  bounced 0
  engaged_seconds_total 0
end
