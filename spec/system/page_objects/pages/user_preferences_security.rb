# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesSecurity < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/security")
        self
      end

      def visit_second_factor(password)
        click_button "Manage Two-Factor Authentication"

        find(".dialog-body input#password").fill_in(with: password)
        find(".dialog-body .btn-primary").click
      end
    end
  end
end
