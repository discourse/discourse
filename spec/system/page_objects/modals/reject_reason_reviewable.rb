# frozen_string_literal: true

module PageObjects
  module Modals
    class RejectReasonReviewable < PageObjects::Modals::Base
      def modal
        browser_root.locator(".reject-reason-reviewable-modal").filter(visible: true)
      end

      def select_send_rejection_email_checkbox
        modal
          .locator(".reject-reason-reviewable-modal__send_email--inline")
          .filter(visible: true)
          .check
      end

      def fill_in_rejection_reason(reason)
        modal
          .locator(".reject-reason-reviewable-modal__explain-reviewable textarea")
          .filter(visible: true)
          .fill(reason)
      end

      def delete_user
        modal.locator(".d-modal__footer .btn.btn-danger").filter(visible: true).click
      end
    end
  end
end
