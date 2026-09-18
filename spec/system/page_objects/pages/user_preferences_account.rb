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

      def has_no_avatar_editor?
        has_no_css?("#edit-avatar")
      end

      def has_custom_uploaded_avatar_image?(upload_id)
        has_css?(".pref-avatar img.avatar[src*='/#{upload_id}_']") do |avatar|
          avatar.evaluate_script("this.complete && this.naturalWidth") ==
            avatar[:src].split("/")[-2].to_i
        end
      end

      def has_system_avatar_image?
        has_css?(".pref-avatar img.avatar[src*='letter_avatar']")
      end
    end
  end
end
