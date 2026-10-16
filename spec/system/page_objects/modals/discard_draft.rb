# frozen_string_literal: true
module PageObjects
  module Modals
    class DiscardDraft < PageObjects::Modals::Base
      MODAL_SELECTOR = ".discard-draft-modal"

      def open?
        have_count(0).does_not_match?(
          browser_root.locator(".d-modal#{MODAL_SELECTOR}").filter(visible: true),
        )
      end

      def closed?
        have_count(0).matches?(
          browser_root.locator(".d-modal#{MODAL_SELECTOR}").filter(visible: true),
        )
      end

      def click_discard
        footer.locator(".discard-draft-modal__discard-btn").filter(visible: true).click
      end

      def click_cancel
        footer.locator(".discard-draft-modal__cancel-btn").filter(visible: true).click
      end
    end
  end
end
