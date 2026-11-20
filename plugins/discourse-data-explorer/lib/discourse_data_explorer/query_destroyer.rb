# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryDestroyer
    def self.destroy(query:)
      Query.transaction do
        query.update!(hidden: true)
        ::AdminDashboard::Reports::Mounter.unmount(
          source: AdminDashboardReportProvider::SOURCE_NAME,
          identifier: query.id.to_s,
        )
      end
    end
  end
end
