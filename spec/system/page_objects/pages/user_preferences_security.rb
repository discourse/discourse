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

      def visit_second_factor(user, password)
        click_manage_2fa_authentication.submit_password(password)

        expect(page).to have_current_path("/u/#{user.username}/preferences/second-factor")
        self
      end
    end
  end
end
