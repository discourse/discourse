# frozen_string_literal: true
module PageObjects
  module Pages
    class UserResetPassword < PageObjects::Pages::Base
      def has_no_toggle_button_to_second_factor_form?
        page.has_no_css?("#security-key .toggle-second-factor-method")
      end

      def has_no_toggle_button_in_second_factor_form?
        page.has_no_css?("#second-factor .toggle-second-factor-method")
      end

      def has_totp_description?
        page.find(".second-factor__description").has_text?(
          I18n.t("js.login.second_factor_description"),
        )
      end

      def has_backup_codes_description?
        page.find(".second-factor__description").has_text?(
          I18n.t("js.login.second_factor_backup_description"),
        )
      end

      def has_logged_in_user?
        page.has_css?(".header-dropdown-toggle.current-user")
      end

      def use_totp
        find(".toggle-second-factor-method", text: I18n.t("js.user.second_factor.use")).click
      end

      def use_backup_codes
        find(".toggle-second-factor-method", text: I18n.t("js.user.second_factor_backup.use")).click
        self
      end

      def try_another_way
        find("#security-key .toggle-second-factor-method").click
        self
      end

      def submit_security_key
        find("#security-key-authenticate-button").click
        self
      end

      def fill_in_new_password(password)
        find("#new-account-password").fill_in(with: password)
        self
      end

      def submit_new_password
        find(".change-password-form .btn-primary").click
        self
      end

      def fill_in_backup_code(backup_code)
        find("#second-factor .second-factor-token-input").fill_in(with: "iAmValidBackupCode")
        self
      end

      def submit_backup_code
        find(".change-password-form .btn-primary").click
        self
      end

      def fill_in_totp(totp)
        find("#second-factor .second-factor-token-input").fill_in(with: totp)
        self
      end

      def submit_totp
        find(".change-password-form .btn-primary").click
        self
      end
    end
  end
end
