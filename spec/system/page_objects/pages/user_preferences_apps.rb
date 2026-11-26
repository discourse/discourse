# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesApps < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/apps")
        self
      end
    end
  end
end
