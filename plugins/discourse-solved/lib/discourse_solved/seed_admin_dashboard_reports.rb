# frozen_string_literal: true

module DiscourseSolved
  class SeedAdminDashboardReports
    REPORT_IDENTIFIER = "accepted_solutions"

    def self.create
      new.create
    end

    def create
      return if SiteSetting.discourse_solved_admin_dashboard_seeded
      return if !solved_in_use?

      ::AdminDashboardReport.find_or_create_by!(
        source: ::AdminDashboard::Reports::CoreReportProvider::SOURCE_NAME,
        identifier: REPORT_IDENTIFIER,
      ) { |row| row.position = ::AdminDashboardReport.maximum(:position).to_i + 1 }

      SiteSetting.set(:discourse_solved_admin_dashboard_seeded, true)
    end

    private

    def solved_in_use?
      SiteSetting.allow_solved_on_all_topics ||
        ::CategoryCustomField.where(name: "enable_accepted_answers", value: "true").exists?
    end
  end
end
