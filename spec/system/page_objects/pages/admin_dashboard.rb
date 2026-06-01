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
          has_css?(".db-date-range__trigger-label", text: preset_label(period))
        end
      end

      def select_preset(period)
        open_custom_date_range
        find(".d-date-range-picker__preset", text: preset_label(period)).click
        self
      end

      def has_custom_label_text?(text)
        has_css?(".db-date-range__trigger-label", text: text)
      end

      def open_custom_date_range
        find(".db-date-range__trigger").click
        has_css?(".d-date-range-picker")
        self
      end

      def select_sidebar_preset(label)
        find(".d-date-range-picker__preset", text: label).click
        self
      end

      def pick_calendar_day(date)
        moment_date = Date.parse(date.to_s)
        aria_label = moment_date.strftime("%B %-d, %Y")
        find(".d-date-range-picker__day[aria-label='#{aria_label}']:not(.--muted)").click
        self
      end

      def apply_custom_range
        find(".d-date-range-picker__apply").click
        self
      end

      def cancel_custom_range
        find(".d-date-range-picker__cancel").click
        self
      end

      def dismiss_picker_via_escape
        find(".d-date-range-picker").send_keys :escape
        self
      end

      def has_no_picker_open?
        has_no_css?(".d-date-range-picker")
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
