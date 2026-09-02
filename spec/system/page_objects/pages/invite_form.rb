# frozen_string_literal: true

module PageObjects
  module Pages
    class InviteForm < PageObjects::Pages::Base
      def open(key)
        visit "/invites/#{key}"
      end

      def fill_username(username)
        find("#new-account-username").fill_in(with: username)
      end

      def fill_password(password)
        find("#new-account-password").fill_in(with: password)
      end

      def has_valid_username?
        find(".username-input").has_css?("#username-validation.good")
      end

      def has_valid_password?
        find(".password-input").has_css?("#password-validation.good")
      end

      def has_valid_fields?
        has_valid_username?
        has_valid_password?
      end

      def click_create_account
        find(".invitation-cta__accept.btn-primary").click
      end

      def has_successful_message?
        has_css?(".invite-success")
      end

      def has_email_code_request?
        has_css?(".code-login-form__email-step .code-login-form__continue")
      end

      def has_no_password_field?
        has_no_field?("new-account-password")
      end

      def request_email_code
        find(".code-login-form__email-step .code-login-form__continue").click
      end

      def has_email_code_entry?
        has_css?(".code-login-form__code-step .d-otp-input")
      end

      def enter_email_code(code)
        find(".d-otp-input").fill_in(with: code)
      end

      def has_account_ready_step?
        has_css?(".code-login-form__complete-step")
      end

      def choose_code_signup_username(username)
        find("#code-login-username").fill_in(with: username)
      end

      def continue_code_signup
        find(".code-login-form__continue-to-site").click
      end
    end
  end
end
