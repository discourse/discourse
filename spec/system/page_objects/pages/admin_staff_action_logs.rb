# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminStaffActionLogs < PageObjects::Pages::Base
      def visit
        browser_page
          .goto("admin/logs/staff_action_logs")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def log_row_selector(user_history)
        ".staff-logs tr[data-user-history-id='#{user_history.id}']"
      end

      def log_row(user_history)
        browser_root.locator(log_row_selector(user_history)).filter(visible: true)
      end

      def has_log_row?(user_history)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(log_row_selector(user_history)).filter(visible: true),
        )
      end

      def has_no_log_row?(user_history)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(log_row_selector(user_history)).filter(visible: true),
        )
      end

      def has_no_injected_detail_element?(user_history)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{log_row_selector(user_history)} .details img[onerror]").filter(
            visible: true,
          ),
        )
      end

      def has_details_text?(user_history, text)
        PlaywrightMatchers.contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator("#{log_row_selector(user_history)} .details").filter(visible: true),
        )
      end

      def show_details(user_history)
        log_row(user_history)
          .locator(".details a")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("admin_js.admin.logs.staff_actions.show")))
          .click
      end

      def filter_by_action(action)
        filter = PageObjects::Components::SelectKit.new("#staff-action-logs-action-filter")
        filter.search(I18n.t("admin_js.admin.logs.staff_actions.actions.#{action}"))
        filter.select_row_by_value(action.to_s)
      end

      def clear_filter
        browser_root.locator(".clear-filters").filter(visible: true).click
      end

      def click_export_button
        browser_root.locator(".export-staff-action-logs").filter(visible: true).click
      end

      def fill_date_filter_from(date)
        browser_root
          .locator(".d-date-time-input.from .d-date-input input")
          .filter(visible: true)
          .fill(date.is_a?(String) ? date : date.to_date.iso8601)
      end

      def fill_date_filter_to(date)
        browser_root
          .locator(".d-date-time-input.to .d-date-input input")
          .filter(visible: true)
          .fill(date.is_a?(String) ? date : date.to_date.iso8601)
      end
    end
  end
end
