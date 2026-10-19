# frozen_string_literal: true

module PageObjects
  module Modals
    class ForgotPassword < Base
      MODAL_SELECTOR = ".forgot-password-modal"

      def request_reset
        find("#{full_modal_selector} .forgot-password-reset").click
        self
      end

      def submit_code(code)
        find("#{full_modal_selector} .d-otp-input").fill_in(with: code)
        self
      end
    end
  end
end
