# frozen_string_literal: true

module PageObjects
  module Modals
    class RejectReasonReviewable < PageObjects::Modals::Base
      def modal
        find(".reject-reason-reviewable-modal")
      end

      def select_send_rejection_email_checkbox
        modal.find(".reject-reason-reviewable-modal__send_email--inline").check
      end

      def fill_in_rejection_reason(reason)
        modal.find(".reject-reason-reviewable-modal__explain-reviewable textarea").fill_in(
          with: reason,
        )
      end

      def delete_user
        modal.find(".d-modal__footer .btn.btn-danger").click
      end
    end
  end
end
