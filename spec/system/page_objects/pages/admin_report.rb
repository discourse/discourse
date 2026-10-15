# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminReport < PageObjects::Pages::Base
      def visit_index(group: nil)
        browser_page
          .goto("/admin/reports#{group ? "?group=#{group}" : ""}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_default_dashboard_report
        browser_page
          .goto("/admin/reports/#{SeedData::AdminDashboardReports::DEFAULT_BUILTIN_REPORTS.first}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_back_to_dashboard?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .get_by_role("link")
            .and(
              browser_root.locator(
                "[id=#{"Back to dashboard".to_s.to_json}], [name=#{"Back to dashboard".to_s.to_json}]",
              ).or(browser_root.get_by_role("link", name: "Back to dashboard")),
            )
            .filter(visible: true),
        )
      end

      def has_no_back_to_dashboard?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root
            .get_by_role("link")
            .and(
              browser_root.locator(
                "[id=#{"Back to dashboard".to_s.to_json}], [name=#{"Back to dashboard".to_s.to_json}]",
              ).or(browser_root.get_by_role("link", name: "Back to dashboard")),
            )
            .filter(visible: true),
        )
      end

      def has_back_to_all_reports?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .get_by_role("link")
            .and(
              browser_root.locator(
                "[id=#{"Back to all reports".to_s.to_json}], [name=#{"Back to all reports".to_s.to_json}]",
              ).or(browser_root.get_by_role("link", name: "Back to all reports")),
            )
            .and(browser_root.locator("[href=#{"/admin/reports".to_s.to_json}]"))
            .filter(visible: true),
        )
      end

      def has_no_back_to_all_reports?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root
            .get_by_role("link")
            .and(
              browser_root.locator(
                "[id=#{"Back to all reports".to_s.to_json}], [name=#{"Back to all reports".to_s.to_json}]",
              ).or(browser_root.get_by_role("link", name: "Back to all reports")),
            )
            .filter(visible: true),
        )
      end

      def go_back
        browser_root.locator(".back-button").filter(visible: true).click
        self
      end

      def filter_controls
        PageObjects::Components::DFilterControls.new(".d-filter-controls")
      end

      CATEGORY_FILTER = ".admin-report .chart__additional-filters .multiple-categories-selector"

      def visit_report(type)
        browser_page
          .goto("/admin/reports/#{type}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_rendered_report?(type)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".admin-report.#{type.tr("_", "-")}").filter(visible: true),
        )
      end

      def has_category_filter?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(CATEGORY_FILTER).filter(visible: true),
        )
      end

      def category_filter
        PageObjects::Components::SelectKit.new(CATEGORY_FILTER)
      end

      def has_selected_category?(category)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{CATEGORY_FILTER} .selected-choice[data-value='#{category.id}']",
          ).filter(visible: true),
        )
      end

      def has_group?(name)
        PlaywrightMatchers.contain_text([browser_text_pattern(name)], useInnerText: true).matches?(
          browser_root.locator(".admin-reports-group__title").filter(visible: true),
        )
      end

      def has_no_group?(name)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(name)],
          useInnerText: true,
        ).does_not_match?(browser_root.locator(".admin-reports-group__title").filter(visible: true))
      end

      def has_report?(title)
        PlaywrightMatchers.contain_text([browser_text_pattern(title)], useInnerText: true).matches?(
          browser_root.locator(".admin-section-landing-item__title").filter(visible: true),
        )
      end

      def has_no_report?(title)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(title)],
          useInnerText: true,
        ).does_not_match?(
          browser_root.locator(".admin-section-landing-item__title").filter(visible: true),
        )
      end

      def has_current_all_reports_path?
        PlaywrightMatchers.have_url("/admin/reports").matches?(browser_page)
      end

      def has_current_reports_path?(group: nil)
        PlaywrightMatchers.have_url("/admin/reports#{group ? "?group=#{group}" : ""}").matches?(
          browser_page,
        )
      end
    end
  end
end
