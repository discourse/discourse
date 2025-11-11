# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesNotifications < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences/notifications")
        self
      end

      def has_notify_on_linked_posts_enabled?
        has_css?(".pref-notify-on-linked-posts input[type='checkbox']:checked")
      end

      def has_notify_on_linked_posts_disabled?
        has_css?(".pref-notify-on-linked-posts input[type='checkbox']:not(:checked)")
      end

      def toggle_notify_on_linked_posts
        find(".pref-notify-on-linked-posts input[type='checkbox']").click
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
