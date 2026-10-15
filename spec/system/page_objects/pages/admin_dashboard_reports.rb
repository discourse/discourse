# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminDashboardReports < PageObjects::Pages::Base
      SECTION_SELECTOR = ".db-main [data-section-id='reports']"

      def has_section?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(SECTION_SELECTOR).filter(visible: true),
        )
      end

      def card_identifiers
        within_browser(SECTION_SELECTOR) do
          browser_root
            .locator(".db-report__card")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map { |el| el.get_attribute("data-identifier") }
        end
      end

      def has_cards_in_order?(identifiers)
        PlaywrightMatchers.have_count(identifiers.size).matches?(
          browser_root.locator("#{SECTION_SELECTOR} .db-report__card").filter(visible: true),
        ) &&
          identifiers.each_with_index.all? do |identifier, index|
            PlaywrightMatchers.have_count(0).does_not_match?(
              browser_root.locator(
                "#{SECTION_SELECTOR} .db-report__card:nth-child(#{index + 1})[data-identifier='#{identifier}']",
              ).filter(visible: true),
            )
          end
      end

      def has_card?(identifier)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}']",
          ).filter(visible: true),
        )
      end

      def has_card_size?(identifier, rows:, cols:)
        selector = "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}']"
        selector += cols > 1 ? ".--wide" : ":not(.--wide)"
        selector += rows > 1 ? ".--rows-#{rows}" : ":not([class*='--rows-'])"
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(selector).filter(visible: true),
        )
      end

      def has_default_report?
        has_card?(default_report_identifier)
      end

      def has_no_card?(identifier)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}']",
          ).filter(visible: true),
        )
      end

      def has_add_tile?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{SECTION_SELECTOR} .db-report__add-report").filter(visible: true),
        )
      end

      def has_no_add_tile?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{SECTION_SELECTOR} .db-report__add-report").filter(visible: true),
        )
      end

      def has_cog?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{SECTION_SELECTOR} .db-section__header-action .btn").filter(
            visible: true,
          ),
        )
      end

      def has_no_cog?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{SECTION_SELECTOR} .db-section__header-action .btn").filter(
            visible: true,
          ),
        )
      end

      def has_no_remove_button?(identifier)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}'] .db-report__remove",
          ).filter(visible: true),
        )
      end

      def open_default_report
        within_browser(
          browser_root.locator(
            "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{default_report_identifier}']",
          ).filter(visible: true),
        ) { browser_root.locator(".db-report__name").filter(visible: true).click }
        self
      end

      def open_manage_reports_via_tile
        browser_root
          .locator("#{SECTION_SELECTOR} .db-report__add-report")
          .filter(visible: true)
          .click
        self
      end

      def open_manage_reports_via_cog
        within_browser(SECTION_SELECTOR) do
          browser_root.locator(".db-section__header-action .btn").filter(visible: true).click
        end
        self
      end

      def manage_reports_modal
        PageObjects::Components::ManageableRowListModal.new(
          ".manage-reports",
          "admin_js.admin.dashboard.reports_section.modal.counter",
        )
      end

      def has_label_for?(identifier, label)
        PlaywrightMatchers.contain_text([browser_text_pattern(label)], useInnerText: true).matches?(
          browser_root.locator(
            "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}'] .db-report__label",
          ).filter(visible: true),
        )
      end

      def has_no_label_for?(identifier)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}'] .db-report__label",
          ).filter(visible: true),
        )
      end

      def has_empty_state_for?(identifier)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}'] .db-report__empty",
          ).filter(visible: true),
        )
      end

      private

      def default_report_identifier
        "#{::AdminDashboard::Reports::CoreReportProvider::SOURCE_NAME}:#{SeedData::AdminDashboardReports::DEFAULT_BUILTIN_REPORTS.first}"
      end
    end
  end
end
