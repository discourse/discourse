# frozen_string_literal: true

module PageObjects
  module Pages
    class InviteForm < PageObjects::Pages::Base
      def open(key)
        browser_page.goto("/invites/#{key}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def fill_username(username)
        browser_root.locator("#new-account-username").filter(visible: true).fill(username)
      end

      def fill_password(password)
        browser_root.locator("#new-account-password").filter(visible: true).fill(password)
      end

      def has_valid_username?
        have_count(0).does_not_match?(
          browser_root
            .locator(".username-input")
            .filter(visible: true)
            .locator("#username-validation.good")
            .filter(visible: true),
        )
      end

      def has_valid_password?
        have_count(0).does_not_match?(
          browser_root
            .locator(".password-input")
            .filter(visible: true)
            .locator("#password-validation.good")
            .filter(visible: true),
        )
      end

      def has_valid_fields?
        has_valid_username?
        has_valid_password?
      end

      def click_create_account
        browser_root.locator(".invitation-cta__accept.btn-primary").filter(visible: true).click
      end

      def has_successful_message?
        have_count(0).does_not_match?(browser_root.locator(".invite-success").filter(visible: true))
      end

      def has_email_code_request?
        have_count(0).does_not_match?(
          browser_root.locator(".code-login-form__email-step .code-login-form__continue").filter(
            visible: true,
          ),
        )
      end

      def has_no_password_field?
        have_count(0).matches?(
          browser_root
            .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
            .and(
              browser_root.locator(
                "[id=#{"new-account-password".to_s.to_json}], [name=#{"new-account-password".to_s.to_json}]",
              ).or(browser_root.get_by_label("new-account-password", exact: true)),
            )
            .filter(visible: true),
        )
      end

      def has_introduction?
        have_count(0).does_not_match?(
          browser_root.locator(".login-welcome-header").filter(visible: true),
        ) &&
          have_count(0).does_not_match?(
            browser_root.locator(".invited-by").filter(visible: true),
          ) &&
          have_count(0).does_not_match?(
            browser_root.locator(".email-message").filter(visible: true),
          )
      end

      def has_no_introduction?
        have_count(0).matches?(
          browser_root.locator(".login-welcome-header, .invited-by, .email-message").filter(
            visible: true,
          ),
        )
      end

      def has_progress_steps?(completed:)
        have_count(3).matches?(
          browser_root.locator(".signup-progress-bar__segment").filter(visible: true),
        ) &&
          have_count(completed).matches?(
            browser_root.locator(".signup-progress-bar__segment.--completed").filter(visible: true),
          )
      end

      def request_email_code
        browser_root
          .locator(".code-login-form__email-step .code-login-form__continue")
          .filter(visible: true)
          .click
      end

      def has_email_code_entry?
        have_count(0).does_not_match?(
          browser_root.locator(".code-login-form__code-step .d-otp-input").filter(visible: true),
        )
      end

      def enter_email_code(code)
        browser_root.locator(".d-otp-input").filter(visible: true).fill(code)
      end

      def has_account_ready_step?
        have_count(0).does_not_match?(
          browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
        )
      end

      def choose_code_signup_username(username)
        browser_root.locator("#code-login-username").filter(visible: true).fill(username)
      end

      def continue_code_signup
        browser_root.locator(".code-login-form__continue-to-site").filter(visible: true).click
      end
    end
  end
end
