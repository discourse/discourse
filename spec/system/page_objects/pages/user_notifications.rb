# frozen_string_literal: true

module PageObjects
  module Pages
    class UserNotifications < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/notifications")
        self
      end

      def filter_dropdown
        PageObjects::Components::SelectKit.new(".notifications-filter")
      end

      def set_filter_value(value)
        filter_dropdown.select_row_by_value(value)
      end

      def has_selected_filter_value?(value)
        expect(filter_dropdown).to have_selected_value(value)
      end

      def has_notification?(notification)
        page.has_css?(".notification a[href='#{notification.url}']")
      end

      def has_no_notification?(notification)
        page.has_no_css?(".notification a[href='#{notification.url}']")
      end

      # def click_edit_avatar_button
      # page.find_button("edit-avatar").click
      # end

      # def open_avatar_selector_modal(user)
      # visit(user).click_edit_avatar_button
      # end

      # def has_custom_uploaded_avatar_image?
      # has_css?(".pref-avatar img.avatar[src*='user_avatar']")
      # end

      # def has_system_avatar_image?
      # has_css?(".pref-avatar img.avatar[src*='letter_avatar']")
      # end
    end
  end
end
