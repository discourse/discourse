# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesInterface < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/interface")
        self
      end

      def has_bookmark_after_notification_mode?(value)
        page.has_css?(
          "#bookmark-after-notification-mode .select-kit-header[data-value=\"#{value}\"]",
        )
      end

      def select_bookmark_after_notification_mode(value)
        page.find("#bookmark-after-notification-mode").click
        page.find(".select-kit-row[data-value=\"#{value}\"]").click
        self
      end

      def save_changes
        click_button "Save Changes"
        expect(page).to have_content(I18n.t("js.saved"))
        self
      end
    end
  end
end
