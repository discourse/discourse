# frozen_string_literal: true

module PageObjects
  module Modals
    class ForgotPassword < Base
      MODAL_SELECTOR = ".forgot-password-modal"

      def request_reset
        browser_root
          .locator("#{full_modal_selector} .forgot-password-reset")
          .filter(visible: true)
          .click
        self
      end

      def submit_code(code)
        browser_root.locator("#{full_modal_selector} .d-otp-input").filter(visible: true).fill(code)
        self
      end
    end
  end
end
