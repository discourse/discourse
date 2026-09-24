# frozen_string_literal: true

module PageObjects
  module Pages
    class CodeSignup < PageObjects::Pages::Base
      def open
        visit("/signup")
        self
      end

      def submit_email(email)
        find(".code-login-form__email-step input[type='email']").fill_in(with: email)
        find(".code-login-form__continue").click
        self
      end

      def submit_code(code)
        find(".d-otp-input").fill_in(with: code)
        self
      end

      def fill_username(username)
        fill_in("code-login-username", with: username)
        self
      end

      def submit_for_approval
        find(".code-login-form__submit-approval:not([disabled])").click
        self
      end

      def has_account_details?
        has_css?(".code-login-form__account-details-step")
      end

      def has_username?(username)
        has_field?("code-login-username", with: username)
      end

      def has_error?(message)
        has_css?(".code-login-form__error", text: message)
      end

      def has_pending_approval?
        has_css?(".code-login-form__pending-approval-step")
      end
    end
  end
end
