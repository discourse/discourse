# frozen_string_literal: true
module PageObjects
  module Modals
    class DiscardDraft < PageObjects::Modals::Base
      MODAL_SELECTOR = ".discard-draft-modal"

      def open?
        has_css?(".modal.d-modal#{MODAL_SELECTOR}")
      end

      def closed?
        has_no_css?(".modal.d-modal#{MODAL_SELECTOR}")
      end

      def click_discard
        footer.find(".discard-draft-modal__discard-btn").click
      end

      def click_cancel
        footer.find(".discard-draft-modal__cancel-btn").click
      end
    end
  end
end
