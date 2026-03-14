# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesBoostsNotifications < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/notifications")
        self
      end

      def boost_notifications_level_dropdown
        PageObjects::Components::SelectKit.new(".boosts-notifications .combo-box")
      end

      def has_boost_notifications_level?(value)
        boost_notifications_level_dropdown.has_selected_value?(value)
      end

      def change_boost_notifications_level(value)
        boost_notifications_level_dropdown.expand
        boost_notifications_level_dropdown.select_row_by_value(value)
        self
      end

      def save_changes
        click_button "Save Changes"
        expect(page).to have_css(".saved")
        self
      end
    end
  end
end
