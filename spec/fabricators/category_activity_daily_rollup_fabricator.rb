# frozen_string_literal: true

Fabricator(:category_activity_daily_rollup) do
  date { Time.zone.today }
  category
  topics 1
  posts 1
  page_views 1
end
