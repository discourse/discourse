# frozen_string_literal: true

Rails.application.config.after_initialize do
  AdminDashboardData.reset_problem_checks
end
