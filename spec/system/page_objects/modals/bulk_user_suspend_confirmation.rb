# frozen_string_literal: true

module PageObjects
  module Modals
    class BulkUserSuspendConfirmation < Base
      MODAL_SELECTOR = ".bulk-user-suspend-confirmation"

      def confirm
        confirm_button.click
      end

      def confirm_button
        within(modal) { find(".btn.confirm-suspend") }
      end

      def has_confirm_button_disabled?
        within(modal) { has_css?(".btn.confirm-suspend[disabled]") }
      end

      def has_confirm_button_enabled?
        within(modal) do
          has_no_css?(".btn.confirm-suspend[disabled]") && has_css?(".btn.confirm-suspend")
        end
      end

      def set_future_date(date)
        select = PageObjects::Components::SelectKit.new(".future-date-input details")
        select.expand
        select.select_row_by_value(date)
      end

      def fill_in_reason(reason)
        find("input.suspend-reason").fill_in(with: reason)
      end

      def has_successful_log_entry_for_user?(user:, position:, total:)
        within(modal) do
          has_css?(
            ".bulk-user-suspend-confirmation__progress-line.-success",
            text:
              I18n.t(
                "admin_js.admin.users.bulk_actions.suspend.confirmation_modal.user_suspend_succeeded",
                position:,
                total:,
                username: user.username,
              ),
          )
        end
      end

      def has_no_error_log_entries?
        within(modal) { has_no_css?(".bulk-user-suspend-confirmation__progress-line.-error") }
      end

      private

      def modal
        find(MODAL_SELECTOR)
      end
    end
  end
end
