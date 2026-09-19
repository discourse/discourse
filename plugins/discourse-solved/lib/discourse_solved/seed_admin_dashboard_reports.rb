# frozen_string_literal: true

module DiscourseSolved
  class SeedAdminDashboardReports
    REPORT_IDENTIFIER = "accepted_solutions"

    def self.create
      return if SiteSetting.discourse_solved_admin_dashboard_seeded
      return if !solved_in_use?

      ::AdminDashboardReport.find_or_create_by!(
        source: ::AdminDashboard::Reports::CoreReportProvider::SOURCE_NAME,
        identifier: REPORT_IDENTIFIER,
      )

      SiteSetting.set(:discourse_solved_admin_dashboard_seeded, true)
    end

    def self.solved_in_use?
      SiteSetting.allow_solved_on_all_topics ||
        ::CategoryCustomField.where(name: "enable_accepted_answers", value: "true").exists?
    end
    private_class_method :solved_in_use?
  end
end
