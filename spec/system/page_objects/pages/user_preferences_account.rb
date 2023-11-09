# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesAccount < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/account")
        self
      end

      def click_edit_avatar_button
        page.find_button("edit-avatar").click
      end

      def open_avatar_selector_modal(user)
        visit(user).click_edit_avatar_button
      end

      def has_custom_uploaded_avatar_image?
        has_css?(".pref-avatar img.avatar[src*='user_avatar']")
      end

      def has_system_avatar_image?
        has_css?(".pref-avatar img.avatar[src*='letter_avatar']")
      end
    end
  end
end
