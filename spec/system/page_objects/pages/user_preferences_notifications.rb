# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesNotifications < PageObjects::Pages::Base
      def visit(user)
        browser_page
          .goto("/u/#{user.username}/preferences/notifications")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_notify_on_linked_posts_enabled?
        have_count(0).does_not_match?(
          browser_root.locator(
            ".pref-notify-on-linked-posts input[type='checkbox']:checked",
          ).filter(visible: true),
        )
      end

      def has_notify_on_linked_posts_disabled?
        have_count(0).does_not_match?(
          browser_root.locator(
            ".pref-notify-on-linked-posts input[type='checkbox']:not(:checked)",
          ).filter(visible: true),
        )
      end

      def toggle_notify_on_linked_posts
        browser_root
          .locator(".pref-notify-on-linked-posts input[type='checkbox']")
          .filter(visible: true)
          .click
        self
      end

      def save_changes
        browser_root
          .locator("[id=#{"Save Changes".to_s.to_json}], [name=#{"Save Changes".to_s.to_json}]")
          .or(browser_root.get_by_role("button", name: "Save Changes"))
          .filter(visible: true)
          .click
        expect(browser_root.locator(".saved").filter(visible: true)).not_to have_count(0)
        self
      end
    end
  end
end
