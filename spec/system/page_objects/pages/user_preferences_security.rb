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

      def auth_token_dropdown
        PageObjects::Components::SelectKit.new(".auth-token:first-child .auth-token-dropdown")
      end

      def has_auth_token?(text = nil)
        has_css?(".pref-auth-tokens .auth-token", text:)
      end

      def has_no_auth_token?(text = nil)
        has_no_css?(".pref-auth-tokens .auth-token", text:)
      end

      def has_auth_tokens_section?
        has_css?(".pref-auth-tokens")
      end

      def log_out_all_devices
        find(".pref-auth-tokens .text-danger").click
        self
      end

      def visit_second_factor(user, password)
        click_manage_2fa_authentication.submit_password(password)

        expect(page).to have_current_path("/u/#{user.username}/preferences/second-factor")
        self
      end
    end
  end
end
