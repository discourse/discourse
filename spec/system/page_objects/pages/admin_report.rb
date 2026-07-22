# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminReport < PageObjects::Pages::Base
      def visit_index(group: nil)
        page.visit("/admin/reports#{group ? "?group=#{group}" : ""}")
        self
      end

      def visit_default_dashboard_report
        page.visit(
          "/admin/reports/#{SeedData::AdminDashboardReports::DEFAULT_BUILTIN_REPORTS.first}",
        )
        self
      end

      def has_back_to_dashboard?
        has_link?("Back to dashboard")
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

      def filter_controls
        PageObjects::Components::DFilterControls.new(".d-filter-controls")
      end

      CATEGORY_FILTER = ".admin-report .chart__additional-filters .category-selector"

      def visit_report(type)
        page.visit("/admin/reports/#{type}")
        self
      end

      def has_rendered_report?(type)
        page.has_css?(".admin-report.#{type.tr("_", "-")}")
      end

      def has_category_filter?
        page.has_css?(CATEGORY_FILTER)
      end

      def category_filter
        PageObjects::Components::SelectKit.new(CATEGORY_FILTER)
      end

      def has_selected_category?(category)
        page.has_css?("#{CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']")
      end

      def has_group?(name)
        page.has_css?(".admin-reports-group__title", text: name)
      end

      def has_no_group?(name)
        page.has_no_css?(".admin-reports-group__title", text: name)
      end

      def has_report?(title)
        page.has_css?(".admin-section-landing-item__title", text: title)
      end

      def has_no_report?(title)
        page.has_no_css?(".admin-section-landing-item__title", text: title)
      end

      def has_current_all_reports_path?
        page.has_current_path?("/admin/reports")
      end

      def has_current_reports_path?(group: nil)
        page.has_current_path?("/admin/reports#{group ? "?group=#{group}" : ""}")
      end
    end
  end
end
