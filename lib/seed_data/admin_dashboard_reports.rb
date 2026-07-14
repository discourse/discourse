# frozen_string_literal: true

module SeedData
  class AdminDashboardReports
    DEFAULT_BUILTIN_REPORTS = %w[daily_engaged_users time_to_first_response].freeze

    def self.create
      return if SiteSetting.admin_dashboard_reports_seeded

      DEFAULT_BUILTIN_REPORTS.each do |identifier|
        AdminDashboardReport.find_or_create_by!(
          source: AdminDashboard::Reports::CoreReportProvider::SOURCE_NAME,
          identifier: identifier,
        )
      end

      SiteSetting.set(:admin_dashboard_reports_seeded, true)
    end
  end
end
