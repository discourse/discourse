# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesProfile < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/profile")
        self
      end
    end
  end
end
