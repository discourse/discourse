# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesNavigationMenu < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/navigation-menu")
        self
      end

      def has_navigation_menu_preference_checked?(preference_id)
        has_css?("[data-name=\"#{preference_id}\"] input[type=checkbox]:checked")
      end
    end
  end
end
