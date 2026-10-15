# frozen_string_literal: true

module PageObjects
  module Modals
    class PermanentlyDeleteConfirm < PageObjects::Modals::Base
      MODAL_SELECTOR = ".permanently-delete-confirm-modal"

      def fill_in_confirmation_phrase(phrase)
        body.locator("input.confirmation-phrase").filter(visible: true).fill(phrase)
      end

      def click_danger
        footer.locator(".btn-danger").filter(visible: true).click
      end

      def has_confirm_button_disabled?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{footer_selector} .btn-danger[disabled]").filter(visible: true),
        )
      end
    end
  end
end
