# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesEmail < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/email")
        self
      end

      def change_email(email)
        find("#change-email").fill_in(with: email)
        find(".save-button .btn-primary").click
        self
      end

      def has_success_message?(message)
        has_css?(".alert-success", text: message)
      end
    end
  end
end
