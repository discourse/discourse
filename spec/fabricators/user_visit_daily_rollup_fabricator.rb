# frozen_string_literal: true

Fabricator(:user_visit_daily_rollup) do
  date { Time.zone.today }
  dau 1
  mau 1
end
