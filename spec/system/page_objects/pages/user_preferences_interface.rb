# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesInterface < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/interface")
        self
      end

      def has_bookmark_after_notification_mode?(value)
        bookmark_after_notification_mode_dropdown.has_selected_value?(value)
      end

      def select_bookmark_after_notification_mode(value)
        bookmark_after_notification_mode_dropdown.select_row_by_value(value)
        self
      end

      def save_changes
        find("button", exact_text: I18n.t("js.save"), visible: :all).click
        find(".saved", exact_text: I18n.t("js.saved"))
        self
      end

      def bookmark_after_notification_mode_dropdown
        @bookmark_after_notification_mode_dropdown ||=
          PageObjects::Components::SelectKit.new("#bookmark-after-notification-mode")
      end
    end
  end
end
