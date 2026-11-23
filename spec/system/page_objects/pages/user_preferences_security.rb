# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesSecurity < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/security")
        self
      end

      def click_manage_2fa_authentication
        click_button "Manage Two-Factor Authentication"
        PageObjects::Modals::ConfirmSession.new
      end

      def click_confirm_2fa_access
        within(".user-preferences.second-factor") do
          click_button I18n.t("js.user.confirm_access.title")
        end
        PageObjects::Modals::ConfirmSession.new
      end

      def has_security_key_enrollment?
        has_button?(I18n.t("js.user.second_factor.security_key.add"))
      end

      def click_add_authenticator
        click_button I18n.t("js.user.second_factor.totp.add")
      end

      def has_authenticator_qr_code?
        has_css?(".d-modal .qr-code")
      end

      def visit_second_factor(user, password)
        click_manage_2fa_authentication.submit_password(password)

        expect(page).to have_current_path("/u/#{user.username}/preferences/second-factor")
        self
      end
    end
  end
end
