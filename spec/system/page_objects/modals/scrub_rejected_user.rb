# frozen_string_literal: true

module PageObjects
  module Modals
    class ScrubRejectedUser < PageObjects::Modals::Base
      def modal
        find(".admin-scrub-rejected-user-modal")
      end

      def fill_in_scrub_reason(reason)
        modal.find("input#scrub-reason").fill_in(with: reason)
      end

      def scrub_button
        modal.find(".d-modal__footer .btn.btn-danger")
      end
    end
  end
end
