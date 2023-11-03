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

      def find_avatar_source
        page.find(".pref-avatar img.avatar")[:src]
      end
    end
  end
end
