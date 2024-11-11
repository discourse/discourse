# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminStaffActionLogs < PageObjects::Pages::Base
      def visit
        page.visit "admin/logs/staff_action_logs"
        self
      end

      def log_row_selector(user_history)
        ".staff-logs tr[data-user-history-id='#{user_history.id}']"
      end

      def log_row(user_history)
        find(log_row_selector(user_history))
      end

      def has_log_row?(user_history)
        has_css?(log_row_selector(user_history))
      end

      def has_no_log_row?(user_history)
        has_no_css?(log_row_selector(user_history))
      end

      def filter_by_action(action)
        filter = PageObjects::Components::SelectKit.new("#staff-action-logs-action-filter")
        filter.search(I18n.t("admin_js.admin.logs.staff_actions.actions.#{action}"))
        filter.select_row_by_value(action.to_s)
      end

      def clear_filter
        find(".clear-filters").click
      end
    end
  end
end
