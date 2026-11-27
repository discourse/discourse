# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesAccount < PageObjects::Pages::Base
      SETTINGS = { username: ".pref-username", data_export: ".pref-data-export" }

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

      def has_username_preference?
        has_css?(".pref-username")
      end

      def edit_username(username)
        find(".username-preference__edit-username").click
        find(".username-preference__input").fill_in(with: username)
        find(".username-preference__submit:not([disabled])").click
        self
      end

      def notice(setting = nil)
        PageObjects::Components::AccessNotice.new(SETTINGS[setting])
      end

      def has_request_archive_disabled?
        has_css?(".btn-request-archive[disabled]")
      end
    end
  end
end
