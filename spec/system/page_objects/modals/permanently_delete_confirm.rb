# frozen_string_literal: true

module PageObjects
  module Modals
    class PermanentlyDeleteConfirm < PageObjects::Modals::Base
      MODAL_SELECTOR = ".permanently-delete-confirm-modal"

      def fill_in_confirmation_phrase(phrase)
        body.find("input.confirmation-phrase").fill_in(with: phrase)
      end

      def click_danger
        footer.find(".btn-danger").click
      end

      def has_confirm_button_disabled?
        has_css?("#{footer_selector} .btn-danger[disabled]")
      end
    end
  end
end
