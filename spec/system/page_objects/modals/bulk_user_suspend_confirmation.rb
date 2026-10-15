# frozen_string_literal: true

module PageObjects
  module Modals
    class BulkUserSuspendConfirmation < Base
      MODAL_SELECTOR = ".bulk-user-suspend-confirmation"

      def confirm
        confirm_button.click
      end

      def confirm_button
        within_browser(modal) { browser_root.locator(".btn.confirm-suspend").filter(visible: true) }
      end

      def has_confirm_button_disabled?
        within_browser(modal) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".btn.confirm-suspend[disabled]").filter(visible: true),
          )
        end
      end

      def has_confirm_button_enabled?
        within_browser(modal) do
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(".btn.confirm-suspend[disabled]").filter(visible: true),
          ) &&
            PlaywrightMatchers.have_count(0).does_not_match?(
              browser_root.locator(".btn.confirm-suspend").filter(visible: true),
            )
        end
      end

      def set_future_date(date)
        select = PageObjects::Components::SelectKit.new(".future-date-input details")
        select.expand
        select.select_row_by_value(date)
      end

      def fill_in_reason(reason)
        browser_root.locator("input.suspend-reason").filter(visible: true).fill(reason)
      end

      def has_successful_log_entry_for_user?(user:, position:, total:)
        within_browser(modal) do
          PlaywrightMatchers.contain_text(
            [
              browser_text_pattern(
                I18n.t(
                  "admin_js.admin.users.bulk_actions.suspend.confirmation_modal.user_suspend_succeeded",
                  position:,
                  total:,
                  username: user.username,
                ),
              ),
            ],
            useInnerText: true,
          ).matches?(
            browser_root.locator(".bulk-user-suspend-confirmation__progress-line.-success").filter(
              visible: true,
            ),
          )
        end
      end

      def has_no_error_log_entries?
        within_browser(modal) do
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(".bulk-user-suspend-confirmation__progress-line.-error").filter(
              visible: true,
            ),
          )
        end
      end

      private

      def modal
        browser_root.locator(MODAL_SELECTOR).filter(visible: true)
      end
    end
  end
end
