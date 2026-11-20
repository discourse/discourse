# frozen_string_literal: true

module Jobs
  class DeleteHiddenQueries < ::Jobs::Scheduled
    every 7.days

    def execute(args)
      return unless SiteSetting.data_explorer_enabled

      DiscourseDataExplorer::Query
        .where("id > 0")
        .where(hidden: true)
        .where(
          "(last_run_at IS NULL OR last_run_at < :days_ago) AND updated_at < :days_ago",
          days_ago: 7.days.ago,
        )
        .delete_all

      unmount_missing_queries_from_dashboard
    end

    private

    # Catches cards left behind before deleting a query unmounted it; they're
    # invisible on the dashboard but still count toward its cap.
    def unmount_missing_queries_from_dashboard
      AdminDashboardReport
        .where(source: DiscourseDataExplorer::AdminDashboardReportProvider::SOURCE_NAME)
        .where(<<~SQL)
        identifier IN (SELECT id::text FROM data_explorer_queries WHERE hidden)
        OR (
          identifier NOT LIKE '-%'
          AND identifier NOT IN (SELECT id::text FROM data_explorer_queries)
        )
      SQL
        .delete_all
    end
  end
end
