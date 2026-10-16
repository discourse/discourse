# frozen_string_literal: true

module PageObjects
  module Modals
    class BulkUserDeleteConfirmation < Base
      MODAL_SELECTOR = ".bulk-user-delete-confirmation"

      def confirm
        confirm_button.click
      end

      def confirm_button
        within_browser(modal) { browser_root.locator(".btn.confirm-delete").filter(visible: true) }
      end

      def block_ip_and_email_checkbox
        within_browser(modal) do
          browser_root.locator("input.block-ip-and-email").filter(visible: true)
        end
      end

      def has_confirm_button_disabled?
        within_browser(modal) do
          have_count(0).does_not_match?(
            browser_root.locator(".btn.confirm-delete[disabled]").filter(visible: true),
          )
        end
      end

      def has_confirm_button_enabled?
        within_browser(modal) do
          have_count(0).matches?(
            browser_root.locator(".btn.confirm-delete[disabled]").filter(visible: true),
          ) &&
            have_count(0).does_not_match?(
              browser_root.locator(".btn.confirm-delete").filter(visible: true),
            )
        end
      end

      def fill_in_confirmation_phrase(user_count:, upcase: false)
        phrase =
          I18n.t(
            "admin_js.admin.users.bulk_actions.delete.confirmation_modal.confirmation_phrase",
            count: user_count,
          )
        phrase = phrase.upcase if upcase
        within_browser(modal) do
          browser_root.locator("input.confirmation-phrase").filter(visible: true).fill(phrase)
        end
      end

      def has_successful_log_entry_for_user?(user:, position:, total:)
        within_browser(modal) do
          contain_text(
            [
              browser_text_pattern(
                I18n.t(
                  "admin_js.admin.users.bulk_actions.delete.confirmation_modal.user_delete_succeeded",
                  position:,
                  total:,
                  username: user.username,
                ),
              ),
            ],
            useInnerText: true,
          ).matches?(
            browser_root.locator(".bulk-user-delete-confirmation__progress-line.-success").filter(
              visible: true,
            ),
          )
        end
      end

      def has_no_error_log_entries?
        within_browser(modal) do
          have_count(0).matches?(
            browser_root.locator(".bulk-user-delete-confirmation__progress-line.-error").filter(
              visible: true,
            ),
          )
        end
      end

      def has_error_log_entry?(message)
        within_browser(modal) do
          contain_text([browser_text_pattern(message)], useInnerText: true).matches?(
            browser_root.locator(".bulk-user-delete-confirmation__progress-line.-error").filter(
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
