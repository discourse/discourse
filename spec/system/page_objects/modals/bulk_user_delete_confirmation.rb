# frozen_string_literal: true

module PageObjects
  module Modals
    class BulkUserDeleteConfirmation < Base
      MODAL_SELECTOR = ".bulk-user-delete-confirmation"

      def confirm_button
        within(modal) { find(".btn.confirm-delete") }
      end

      def block_ip_and_email_checkbox
        within(modal) { find("input.block-ip-and-email") }
      end

      def has_confirm_button_disabled?
        within(modal) { has_css?(".btn.confirm-delete[disabled]") }
      end

      def has_confirm_button_enabled?
        within(modal) do
          has_no_css?(".btn.confirm-delete[disabled]") && has_css?(".btn.confirm-delete")
        end
      end

      def fill_in_confirmation_phase(user_count:)
        within(modal) do
          find("input.confirmation-phrase").fill_in(
            with:
              I18n.t(
                "admin_js.admin.users.bulk_actions.delete.confirmation_modal.confirmation_phrase",
                count: user_count,
              ),
          )
        end
      end

      def has_successful_log_entry_for_user?(user:, position:, total:)
        within(modal) do
          has_css?(
            ".bulk-user-delete-confirmation__progress-line.-success",
            text:
              I18n.t(
                "admin_js.admin.users.bulk_actions.delete.confirmation_modal.user_delete_succeeded",
                position:,
                total:,
                username: user.username,
              ),
          )
        end
      end

      def has_no_error_log_entries?
        within(modal) { has_no_css?(".bulk-user-delete-confirmation__progress-line.-error") }
      end

      def has_error_log_entry?(message)
        within(modal) do
          has_css?(".bulk-user-delete-confirmation__progress-line.-error", text: message)
        end
      end

      private

      def modal
        find(MODAL_SELECTOR)
      end
    end
  end
end
