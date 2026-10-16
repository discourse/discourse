# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminDashboard < PageObjects::Pages::Base
      def visit
        browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(
          browser_root.locator(".db-main [data-section-id], .db-main__empty, .nav-pills").filter(
            visible: true,
          ),
        ).not_to have_count(0)
        self
      end

      def visit_with_query(params)
        browser_page
          .goto("/admin?#{params.to_query}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(
          browser_root.locator(".db-main [data-section-id], .db-main__empty, .nav-pills").filter(
            visible: true,
          ),
        ).not_to have_count(0)
        self
      end

      def visit_with_custom_range(from:, to:)
        visit_with_query(custom_range_params(from: from, to: to))
      end

      def has_custom_range?(from:, to:)
        have_url("/admin?#{custom_range_params(from: from, to: to).to_query}").matches?(
          browser_page,
        )
      end

      def has_admin_notice?(message)
        contain_text([browser_text_pattern(message)], useInnerText: true).matches?(
          browser_root.locator(".dashboard-problem").filter(visible: true),
        )
      end

      def has_no_admin_notice?(message)
        contain_text([browser_text_pattern(message)], useInnerText: true).does_not_match?(
          browser_root.locator(".dashboard-problem").filter(visible: true),
        )
      end

      def dismiss_notice(message)
        browser_root
          .locator(".dashboard-problem")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(message))
          .locator(".btn")
          .filter(visible: true)
          .click
      end

      def has_site_advice?
        have_count(0).does_not_match?(browser_root.locator(".db-site-advice").filter(visible: true))
      end

      def has_site_advice_at_top?
        have_count(0).does_not_match?(
          browser_root.locator(".db-main > .db-site-advice:first-child").filter(visible: true),
        )
      end

      def has_no_site_advice?
        have_count(0).matches?(browser_root.locator(".db-site-advice").filter(visible: true))
      end

      def has_site_advice_title?(text)
        contain_text([browser_exact_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(".db-site-advice__header h3").filter(visible: true),
        )
      end

      def has_site_advice_problem?(message)
        contain_text([browser_text_pattern(message)], useInnerText: true).matches?(
          browser_root.locator(".db-site-advice [data-test-site-advice-problem]").filter(
            visible: true,
          ),
        )
      end

      def has_no_site_advice_problem?(message)
        contain_text([browser_text_pattern(message)], useInnerText: true).does_not_match?(
          browser_root.locator(".db-site-advice [data-test-site-advice-problem]").filter(
            visible: true,
          ),
        )
      end

      def has_first_site_advice_problem?(message)
        contain_text([browser_text_pattern(message)], useInnerText: true).matches?(
          browser_root.locator(
            ".db-site-advice [data-test-site-advice-problem]:first-child",
          ).filter(visible: true),
        )
      end

      def has_ignore_button_for?(message)
        within_browser(
          browser_root
            .locator(".db-site-advice [data-test-site-advice-problem]")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(message)),
        ) do
          have_count(0).does_not_match?(
            browser_root.locator("[data-test-site-advice-ignore]").filter(visible: true),
          )
        end
      end

      def has_no_ignore_buttons?
        have_count(0).matches?(
          browser_root.locator(".db-site-advice [data-test-site-advice-ignore]").filter(
            visible: true,
          ),
        )
      end

      def has_site_advice_refresh_button?
        have_count(0).does_not_match?(
          browser_root.locator(".db-site-advice [data-test-site-advice-refresh]").filter(
            visible: true,
          ),
        )
      end

      def ignore_site_advice_problem(message)
        within_browser(
          browser_root
            .locator(".db-site-advice [data-test-site-advice-problem]")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(message)),
        ) { browser_root.locator("[data-test-site-advice-ignore]").filter(visible: true).click }
        self
      end

      def refresh_site_advice
        browser_root
          .locator(".db-site-advice [data-test-site-advice-refresh]")
          .filter(visible: true)
          .click
        self
      end

      def has_redesigned_toolbar?
        have_count(0).does_not_match?(browser_root.locator(".db-toolbar").filter(visible: true))
      end

      def has_active_period?(period)
        if period == "custom"
          browser_page.url.include?("range=custom")
        else
          contain_text([browser_text_pattern(preset_label(period))], useInnerText: true).matches?(
            browser_root.locator(".db-date-range__trigger .d-button-label").filter(visible: true),
          )
        end
      end

      def has_custom_label?(text)
        contain_text([browser_exact_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(".db-date-range__trigger .d-button-label").filter(visible: true),
        )
      end

      def date_range_picker
        PageObjects::Components::AdminDashboardDateRangePicker.new
      end

      def open_custom_date_range
        browser_root.locator(".db-date-range__trigger").filter(visible: true).click
        date_range_picker.tap(&:open?)
      end

      def select_preset(period)
        open_custom_date_range.select_preset(preset_label(period))
        self
      end

      def has_configure_button?
        have_count(0).does_not_match?(
          browser_root.locator(".btn[data-identifier='db-configure']").filter(visible: true),
        )
      end

      def has_no_configure_button?
        have_count(0).matches?(
          browser_root.locator(".btn[data-identifier='db-configure']").filter(visible: true),
        )
      end

      def open_configure_menu
        ensure_redesigned_dashboard

        if browser_root
             .locator(".d-page-header-mobile-actions-trigger")
             .filter(visible: true)
             .count != 0
          browser_root.locator(".d-page-header-mobile-actions-trigger").filter(visible: true).click
        end

        browser_root.locator(".btn[data-identifier='db-configure']").filter(visible: true).click
        expect(browser_root.locator(".db-configure").filter(visible: true)).not_to have_count(0)
        self
      end

      def close_configure_menu
        if browser_root.locator(".d-modal__backdrop").filter(visible: true).count != 0
          browser_page.keyboard.press("Escape")
        else
          browser_root.locator(".btn[data-identifier='db-configure']").filter(visible: true).click
        end
        expect(browser_root.locator(".db-configure").filter(visible: true)).to have_count(0)
        self
      end

      def has_section?(id)
        have_count(0).does_not_match?(
          browser_root.locator(".db-main [data-section-id='#{id}']").filter(visible: true),
        )
      end

      def has_no_section?(id)
        have_count(0).matches?(
          browser_root.locator(".db-main [data-section-id='#{id}']").filter(visible: true),
        )
      end

      def has_first_section?(id)
        have_count(0).does_not_match?(
          browser_root.locator(".db-main > :first-child[data-section-id='#{id}']").filter(
            visible: true,
          ),
        )
      end

      def site_traffic
        PageObjects::Components::AdminDashboardSiteTraffic.new
      end

      def search
        PageObjects::Components::AdminDashboardSearch.new
      end

      def engagement
        PageObjects::Components::AdminDashboardEngagement.new
      end

      def section_ids_in_order
        browser_root
          .locator(".db-main [data-section-id]")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |el| el.get_attribute("data-section-id") }
      end

      def has_empty_state?
        have_count(0).does_not_match?(browser_root.locator(".db-main__empty").filter(visible: true))
      end

      def toggle_section(id)
        within_browser(
          ".db-configure__row[data-section-id='#{id}'], " \
            ".db-configure__row[data-reorderable-key='#{id}']",
        ) { browser_root.locator(".d-toggle-switch__label").filter(visible: true).click }
        self
      end

      def move_section_down(id)
        within_browser(
          browser_root.locator(".db-configure__row[data-section-id='#{id}']").filter(visible: true),
        ) { browser_root.locator(".db-configure__arrow:last-child").filter(visible: true).click }
        self
      end

      # Methods for when the enable_new_reordering_controls upcoming change is

      # enabled. move_section_up/down above keep main's arrow-button behaviour.

      #

      # TODO (ui-kit-reorderable-list-cleanup) fold these over them once the change

      # ships.

      def configure_reorderable(id)
        PageObjects::Components::ReorderableList.new(
          ".db-configure__row[data-reorderable-key='#{id}']",
        )
      end

      def move_section_up_via_list(id)
        configure_reorderable(id).move(:up)

        self
      end

      def move_section_down_via_list(id)
        configure_reorderable(id).move(:down)

        self
      end

      def drag_section(source_id, target_id)
        drag_and_drop(
          source:
            ".db-configure__row[data-reorderable-key='#{source_id}'] .d-reorderable-list__handle",
          target: ".db-configure__row[data-reorderable-key='#{target_id}']",
          target_position: {
            x: 100,
            y: 1,
          },
        )

        self
      end

      def move_section_up(id)
        within_browser(
          browser_root.locator(".db-configure__row[data-section-id='#{id}']").filter(visible: true),
        ) { browser_root.locator(".db-configure__arrow:first-child").filter(visible: true).click }
        self
      end

      private

      def custom_range_params(from:, to:)
        { range: "custom", start_date: from, end_date: to }
      end

      def ensure_redesigned_dashboard
        if browser_root.locator(".db-main").filter(visible: true).count == 0
          browser_page.reload.tap { SystemBrowserBootstrap.wait_for(browser_page) }
        end
        expect(
          browser_root.locator(".db-main [data-section-id], .db-main__empty").filter(visible: true),
        ).not_to have_count(0)
        self
      end

      def preset_label(period)
        case period
        when "last_7_days"
          "Last 7 days"
        when "last_30_days"
          "Last 30 days"
        when "last_3_months"
          "Last 3 months"
        when "last_6_months"
          "Last 6 months"
        when "last_year"
          "Last year"
        end
      end
    end
  end
end
