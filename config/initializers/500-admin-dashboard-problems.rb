# frozen_string_literal: true

Rails.application.reloader.to_prepare do
  AdminDashboardData.reset_problem_checks
end
