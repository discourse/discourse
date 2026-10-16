# frozen_string_literal: true
module PageObjects
  module Pages
    class UserResetPassword < PageObjects::Pages::Base
      def has_no_toggle_button_to_second_factor_form?
        have_count(0).matches?(
          browser_root.locator("#security-key .toggle-second-factor-method").filter(visible: true),
        )
      end

      def has_no_toggle_button_in_second_factor_form?
        have_count(0).matches?(
          browser_root.locator("#second-factor .toggle-second-factor-method").filter(visible: true),
        )
      end

      def has_totp_description?
        contain_text(
          browser_text_pattern(I18n.t("js.login.second_factor_description")),
          useInnerText: true,
        ).matches?(browser_root.locator(".second-factor__description").filter(visible: true))
      end

      def has_backup_codes_description?
        contain_text(
          browser_text_pattern(I18n.t("js.login.second_factor_backup_description")),
          useInnerText: true,
        ).matches?(browser_root.locator(".second-factor__description").filter(visible: true))
      end

      def has_logged_in_user?
        have_count(0).does_not_match?(
          browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
        )
      end

      def use_totp
        browser_root
          .locator(".toggle-second-factor-method")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("js.user.second_factor.use")))
          .click
      end

      def use_backup_codes
        browser_root
          .locator(".toggle-second-factor-method")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("js.user.second_factor_backup.use")))
          .click
        self
      end

      def try_another_way
        browser_root
          .locator("#security-key .toggle-second-factor-method")
          .filter(visible: true)
          .click
        self
      end

      def submit_security_key
        browser_root.locator("#security-key-authenticate-button").filter(visible: true).click
        self
      end

      def fill_in_new_password(password)
        browser_root.locator("#new-account-password").filter(visible: true).fill(password)
        self
      end

      def submit_new_password
        browser_root.locator(".change-password-form .btn-primary").filter(visible: true).click
        self
      end

      def fill_in_backup_code(backup_code)
        browser_root
          .locator("#second-factor .second-factor-token-input")
          .filter(visible: true)
          .fill("iAmValidBackupCode")
        self
      end

      def submit_backup_code
        browser_root.locator(".change-password-form .btn-primary").filter(visible: true).click
        self
      end

      def fill_in_totp(totp)
        browser_root
          .locator("#second-factor .second-factor-token-input")
          .filter(visible: true)
          .fill(totp)
        self
      end

      def submit_totp
        browser_root.locator(".change-password-form .btn-primary").filter(visible: true).click
        self
      end
    end
  end
end
