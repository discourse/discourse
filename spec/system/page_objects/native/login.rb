# frozen_string_literal: true
module PageObjects
  module Native
    class Login
      def initialize(page)
        @page = page
      end

      def visit
        @page.goto("/login")
      end

      def visit_code_login
        @page.goto("/login?mode=code")
      end

      def account_name
        @page.locator("#login-account-name")
      end

      def account_password
        @page.locator("#login-account-password")
      end

      def code_login_link
        @page.locator("#one-time-code-link")
      end

      def email_login_link
        @page.locator("#email-login-link")
      end

      def form
        @page.locator(".code-login-form:visible")
      end

      def email_step
        @page.locator(".code-login-form__email-step:visible")
      end

      def email_input
        @page.locator(".code-login-form__email-step input[type='email']")
      end

      def continue_button
        @page.locator(".code-login-form__continue")
      end

      def code_step
        @page.locator(".code-login-form__code-step:visible")
      end

      def code_input
        @page.locator(".d-otp-input")
      end

      def resend_button
        @page.locator(".code-login-form__resend")
      end

      def error
        @page.locator(".code-login-form__error:visible")
      end

      def current_user
        @page.locator(".header-dropdown-toggle.current-user:visible")
      end

      def second_factor_step
        @page.locator(".code-login-form__second-factor-step:visible")
      end

      def second_factor_input
        @page.locator(".second-factor-token-input")
      end

      def second_factor_verify
        @page.locator(".code-login-form__second-factor-step .code-login-form__verify")
      end

      def password_toggle
        @page.locator(".code-login-form__password-toggle")
      end

      def login_button
        @page.locator("#login-button")
      end

      def user_fields_step
        @page.locator(".code-login-form__user-fields-step:visible")
      end

      def terms_checkbox
        @page.locator(".user-field.confirm input[type='checkbox']")
      end

      def user_fields_verify
        @page.locator(".code-login-form__user-fields-step .code-login-form__verify")
      end

      def signup_details_step
        @page.locator(".code-login-form__signup-details-step:visible")
      end

      def signup_username
        @page.locator("#code-login-username")
      end

      def continue_to_site
        @page.locator(".code-login-form__continue-to-site")
      end
    end
  end
end
