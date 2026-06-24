# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminDashboardReports < PageObjects::Pages::Base
      SECTION_SELECTOR = ".db-main [data-section-id='reports']"

      def has_section?
        has_css?(SECTION_SELECTOR)
      end

      def card_identifiers
        within(SECTION_SELECTOR) { all(".db-report__card").map { |el| el["data-identifier"] } }
      end

      def has_card?(identifier)
        has_css?("#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}']")
      end

      def has_no_card?(identifier)
        has_no_css?("#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}']")
      end

      def has_add_tile?
        has_css?("#{SECTION_SELECTOR} .db-report__add-report")
      end

      def has_no_add_tile?
        has_no_css?("#{SECTION_SELECTOR} .db-report__add-report")
      end

      def has_cog?
        has_css?("#{SECTION_SELECTOR} .db-section__header-action .btn")
      end

      def has_no_cog?
        has_no_css?("#{SECTION_SELECTOR} .db-section__header-action .btn")
      end

      def has_no_remove_button?(identifier)
        has_no_css?(
          "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}'] .db-report__remove",
        )
      end

      def open_manage_reports_via_tile
        find("#{SECTION_SELECTOR} .db-report__add-report").click
        self
      end

      def open_manage_reports_via_cog
        within(SECTION_SELECTOR) { find(".db-section__header-action .btn").click }
        self
      end

      def manage_reports_modal
        PageObjects::Components::ManageReportsModal.new
      end

      def has_label_for?(identifier, label)
        has_css?(
          "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}'] .db-report__label",
          text: label,
        )
      end

      def has_no_label_for?(identifier)
        has_no_css?(
          "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}'] .db-report__label",
        )
      end

      def has_empty_state_for?(identifier)
        has_css?(
          "#{SECTION_SELECTOR} .db-report__card[data-identifier='#{identifier}'] .db-report__empty",
        )
      end
    end
  end
end
