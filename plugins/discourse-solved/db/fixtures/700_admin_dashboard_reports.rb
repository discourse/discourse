# frozen_string_literal: true

require "discourse_solved/seed_admin_dashboard_reports"

DiscourseSolved::SeedAdminDashboardReports.create if !Rails.env.test?
