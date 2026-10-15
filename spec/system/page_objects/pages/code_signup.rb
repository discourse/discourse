# frozen_string_literal: true

module PageObjects
  module Pages
    class CodeSignup < PageObjects::Pages::Base
      def open
        browser_page.goto("/signup").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def submit_email(email)
        browser_root
          .locator(".code-login-form__email-step input[type='email']")
          .filter(visible: true)
          .fill(email)
        browser_root.locator(".code-login-form__continue").filter(visible: true).click
        self
      end

      def submit_code(code)
        browser_root.locator(".d-otp-input").filter(visible: true).fill(code)
        self
      end

      def fill_username(username)
        browser_root
          .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
          .and(
            browser_root.locator(
              "[id=#{"code-login-username".to_s.to_json}], [name=#{"code-login-username".to_s.to_json}]",
            ).or(browser_root.get_by_label("code-login-username", exact: true)),
          )
          .filter(visible: true)
          .fill(username)
        self
      end

      def submit_for_approval
        browser_root
          .locator(".code-login-form__submit-approval:not([disabled])")
          .filter(visible: true)
          .click
        self
      end

      def has_account_details?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".code-login-form__account-details-step").filter(visible: true),
        )
      end

      def has_username?(username)
        PlaywrightMatchers.have_value(username).matches?(
          browser_root
            .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
            .and(
              browser_root.locator(
                "[id=#{"code-login-username".to_s.to_json}], [name=#{"code-login-username".to_s.to_json}]",
              ).or(browser_root.get_by_label("code-login-username", exact: true)),
            )
            .filter(visible: true),
        )
      end

      def has_error?(message)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(message)],
          useInnerText: true,
        ).matches?(browser_root.locator(".code-login-form__error").filter(visible: true))
      end

      def has_pending_approval?
        PlaywrightMatchers.be_attached.matches?(
          browser_root.locator(".code-login-form__pending-approval-step"),
        ) &&
          PlaywrightMatchers.contain_text(
            I18n.t("js.code_login.pending_approval_title"),
            useInnerText: true,
          ).matches?(browser_root.locator(".login-title"))
      end
    end
  end
end
