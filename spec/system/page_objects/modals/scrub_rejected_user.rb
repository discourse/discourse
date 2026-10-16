# frozen_string_literal: true

module PageObjects
  module Modals
    class ScrubRejectedUser < PageObjects::Modals::Base
      def modal
        browser_root.locator(".admin-scrub-rejected-user-modal").filter(visible: true)
      end

      def fill_in_scrub_reason(reason)
        modal.locator("input#scrub-reason").filter(visible: true).fill(reason)
      end

      def scrub_button
        modal.locator(".d-modal__footer .btn.btn-danger").filter(visible: true)
      end
    end
  end
end
