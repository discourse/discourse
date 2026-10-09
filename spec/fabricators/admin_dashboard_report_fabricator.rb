# frozen_string_literal: true

Fabricator(:admin_dashboard_report) do
  source "core_report"
  identifier "signups"
end

Fabricator(:tall_admin_dashboard_report, from: :admin_dashboard_report) do
  rows 3
  cols 2
end
