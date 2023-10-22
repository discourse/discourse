# frozen_string_literal: true

module PageObjects
  module Modals
    class RejectReasonReviewable < PageObjects::Pages::Base
      def modal
        find(".reject-reason-reviewable-modal")
      end

      def select_send_rejection_email_checkbox
        modal.check("Send rejection email")
      end

      def fill_in_rejection_reason(reason)
        modal.find(".explain-reviewable textarea").set(reason)
      end
      def delete_user
        modal.find(".modal-footer .btn.btn-danger").click
      end
    end
  end
end
