# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesSecurity < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/security")
        self
      end

      def visit_second_factor(user, password)
        click_button "Manage Two-Factor Authentication"
        find(".confirm-session input#password").fill_in(with: password)
        find(".confirm-session .btn-primary:not([disabled])").click
        expect(page).to have_current_path("/u/#{user.username}/preferences/second-factor")
        self
      end
    end
  end
end
