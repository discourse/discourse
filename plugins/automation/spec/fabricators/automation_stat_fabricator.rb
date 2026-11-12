# frozen_string_literal: true

Fabricator(:automation_stat, from: DiscourseAutomation::Stat) do
  date { Date.current }
  last_run_at { |attributes| attributes[:date].to_time + 10.hours }
  total_time 1.0
  average_run_time 1.0
  min_run_time 1.0
  max_run_time 1.0
  total_runs 1
  total_errors 0
end
