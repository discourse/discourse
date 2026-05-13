# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminDashboard < PageObjects::Pages::Base
      def visit
        page.visit("/admin")
        has_css?(".db-main__section, .db-main__empty, .nav-pills")
        self
      end

      def has_admin_notice?(message)
        has_css?(".dashboard-problem", text: message)
      end

      def has_no_admin_notice?(message)
        has_no_css?(".dashboard-problem", text: message)
      end

      def dismiss_notice(message)
        find(".dashboard-problem", text: message).find(".btn").click
      end

      def has_redesigned_toolbar?
        has_css?(".db-toolbar")
      end

      def has_active_period?(period)
        has_css?(".db-date-range input[value='#{period}']:checked")
      end

      def select_preset(period)
        find(".db-date-range label", text: preset_label(period)).click
        self
      end

      def has_custom_label_text?(text)
        has_css?(".db-date-range__custom", text: text)
      end

      def open_custom_date_range
        find(".db-date-range__custom").click
        self
      end

      def has_configure_button?
        has_css?(".btn[data-identifier='db-configure']")
      end

      def has_no_configure_button?
        has_no_css?(".btn[data-identifier='db-configure']")
      end

      def open_configure_menu
        find(".btn[data-identifier='db-configure']").click
        has_css?(".db-configure")
        self
      end

      def close_configure_menu
        if page.has_css?(".d-modal__backdrop", wait: 0)
          page.send_keys :escape
        else
          find(".btn[data-identifier='db-configure']").click
        end
        has_no_css?(".db-configure")
        self
      end

      def has_section?(id)
        has_css?(".db-main__section[data-section-id='#{id}']")
      end

      def has_no_section?(id)
        has_no_css?(".db-main__section[data-section-id='#{id}']")
      end

      def section_ids_in_order
        all(".db-main__section").map { |el| el["data-section-id"] }
      end

      def has_empty_state?
        has_css?(".db-main__empty")
      end

      def toggle_section(id)
        within(".db-configure__row[data-section-id='#{id}']") do
          find(".d-toggle-switch__label").click
        end
        self
      end

      def move_section_down(id)
        within(".db-configure__row[data-section-id='#{id}']") do
          find(".db-configure__arrow:last-child").click
        end
        self
      end

      def move_section_up(id)
        within(".db-configure__row[data-section-id='#{id}']") do
          find(".db-configure__arrow:first-child").click
        end
        self
      end

      private

      def preset_label(period)
        case period
        when "last_7_days"
          "Last 7 days"
        when "last_30_days"
          "Last 30 days"
        when "last_3_months"
          "Last 3 months"
        end
      end
    end
  end
end
