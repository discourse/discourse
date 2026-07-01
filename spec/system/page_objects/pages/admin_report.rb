# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminReport < PageObjects::Pages::Base
      def visit_default_dashboard_report
        page.visit(
          "/admin/reports/#{SeedData::AdminDashboardReports::DEFAULT_BUILTIN_REPORTS.first}",
        )
        self
      end

      def has_back_to_dashboard?(dashboard)
        has_link?("Back to dashboard", href: dashboard.remembered_request_uri)
      end

      def has_no_back_to_dashboard?
        has_no_link?("Back to dashboard")
      end

      def has_back_to_all_reports?
        has_link?("Back to all reports", href: "/admin/reports")
      end

      def has_no_back_to_all_reports?
        has_no_link?("Back to all reports")
      end

      def go_back
        find(".back-button").click
        self
      end

      def has_current_all_reports_path?
        page.has_current_path?("/admin/reports")
      end
    end
  end
end
