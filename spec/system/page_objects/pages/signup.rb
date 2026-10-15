# frozen_string_literal: true

module PageObjects
  module Pages
    class Signup < PageObjects::Pages::Base
      def open?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".signup-fullpage").filter(visible: true),
        )
      end

      def closed?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".signup-fullpage").filter(visible: true),
        )
      end

      def open
        browser_page.goto("/signup").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def open_from_header
        browser_root.locator(".sign-up-button").filter(visible: true).click
      end

      def click(selector)
        if browser_root.locator("html.mobile-view").filter(visible: true).count != 0
          expect(
            browser_root.locator(".d-modal.is-animating").filter(visible: true),
          ).to PlaywrightMatchers.have_count(0)
        end
        browser_root.locator(selector).filter(visible: true).click
      end

      def open_login
        click("#login-link")
      end

      def click_create_account
        click(".signup-fullpage .btn-primary")
      end

      def has_password_input?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#new-account-password").filter(visible: true),
        )
      end

      def has_no_password_input?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#new-account-password").filter(visible: true),
        )
      end

      def has_name_input?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#new-account-name").filter(visible: true),
        )
      end

      def has_no_name_input?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#new-account-name").filter(visible: true),
        )
      end

      def has_editable_name_input?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#new-account-name:not([disabled])").filter(visible: true),
        )
      end

      def has_disabled_name_input?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#new-account-name[disabled]").filter(visible: true),
        )
      end

      def has_no_right_side_column?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".login-right-side").filter(visible: true),
        )
      end

      def fill_input(selector, text)
        if browser_root.locator("html.mobile-view").filter(visible: true).count != 0
          expect(
            browser_root.locator(".d-modal.is-animating").filter(visible: true),
          ).to PlaywrightMatchers.have_count(0)
        end
        browser_root.locator(selector).filter(visible: true).fill(text)
      end

      def fill_email(email)
        fill_input("#new-account-email", email)
        self
      end

      def fill_username(username)
        fill_input("#new-account-username", username)
        self
      end

      def fill_name(name)
        fill_input("#new-account-name", name)
        self
      end

      def fill_password(password)
        fill_input("#new-account-password", password)
        self
      end

      def fill_code(code)
        fill_input("#inviteCode", code)
        self
      end

      def fill_custom_field(name, value)
        browser_root.locator(".user-field-#{name.downcase} input").filter(visible: true).fill(value)
        self
      end

      def has_valid_email?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .locator(".create-account-email")
            .filter(visible: true)
            .locator("#account-email-validation.good")
            .filter(visible: true),
        )
      end

      def has_valid_username?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .locator(".create-account__username")
            .filter(visible: true)
            .locator("#username-validation.good")
            .filter(visible: true),
        )
      end

      def has_valid_password?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .locator(".create-account__password")
            .filter(visible: true)
            .locator("#password-validation.good")
            .filter(visible: true),
        )
      end

      def has_valid_fields?
        has_valid_email?
        has_valid_username?
        has_valid_password?
      end

      def has_disabled_email?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .locator(".create-account-email")
            .filter(visible: true)
            .locator("input[disabled]")
            .filter(visible: true),
        )
      end

      def has_disabled_name?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .locator(".create-account__fullname")
            .filter(visible: true)
            .locator("input[disabled]")
            .filter(visible: true),
        )
      end

      def has_disabled_username?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root
            .locator(".create-account__username")
            .filter(visible: true)
            .locator("input[disabled]")
            .filter(visible: true),
        )
      end

      def click_social_button(provider)
        click(".btn-social.#{provider}")
      end

      def has_flash_message?(text)
        PlaywrightMatchers.contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(".alert").filter(visible: true),
        )
      end
    end
  end
end
