# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminDashboard < PageObjects::Pages::Base
      def visit
        page.visit("/admin")
        has_css?(".db-main [data-section-id], .db-main__empty, .nav-pills")
        self
      end

      def visit_with_query(params)
        page.visit("/admin?#{params.to_query}")
        has_css?(".db-main [data-section-id], .db-main__empty, .nav-pills")
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
        if period == "custom"
          page.current_url.include?("range=custom")
        else
          has_css?(".db-date-range__trigger .d-button-label", text: preset_label(period))
        end
      end

      def has_custom_label?(text)
        has_css?(".db-date-range__trigger .d-button-label", exact_text: text)
      end

      def date_range_picker
        PageObjects::Components::AdminDashboardDateRangePicker.new
      end

      def open_custom_date_range
        find(".db-date-range__trigger").click
        date_range_picker.tap(&:open?)
      end

      def select_preset(period)
        open_custom_date_range.select_preset(preset_label(period))
        self
      end

      def has_configure_button?
        has_css?(".btn[data-identifier='db-configure']")
      end

      def has_no_configure_button?
        has_no_css?(".btn[data-identifier='db-configure']")
      end

      def open_configure_menu
        ensure_redesigned_dashboard

        if has_css?(".d-page-header-mobile-actions-trigger", wait: 0)
          find(".d-page-header-mobile-actions-trigger").click
        end

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
        has_css?(".db-main [data-section-id='#{id}']")
      end

      def has_no_section?(id)
        has_no_css?(".db-main [data-section-id='#{id}']")
      end

      def has_first_section?(id)
        has_css?(".db-main > :first-child[data-section-id='#{id}']")
      end

      def site_traffic
        PageObjects::Components::AdminDashboardSiteTraffic.new
      end

      def search
        PageObjects::Components::AdminDashboardSearch.new
      end

      def section_ids_in_order
        all(".db-main [data-section-id]").map { |el| el["data-section-id"] }
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

      def ensure_redesigned_dashboard
        page.refresh unless has_css?(".db-main", wait: 0)
        has_css?(".db-main [data-section-id], .db-main__empty")
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
