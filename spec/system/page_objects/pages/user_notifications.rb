# frozen_string_literal: true

module PageObjects
  module Pages
    class UserNotifications < PageObjects::Pages::Base
      def visit(user)
        browser_page
          .goto("/u/#{user.username}/notifications")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def filter_dropdown
        PageObjects::Components::SelectKit.new(".notifications-filter")
      end

      def set_filter_value(value)
        filter_dropdown.select_row_by_value(value)
      end

      def find_notification(notification)
        browser_root.locator(".notification a[href='#{notification.url}']").filter(visible: true)
      end

      def has_selected_filter_value?(value)
        expect(filter_dropdown).to have_selected_value(value)
      end

      def has_notification?(notification)
        have_count(0).does_not_match?(
          browser_root.locator(".notification a[href='#{notification.url}']").filter(visible: true),
        )
      end

      def has_no_notification?(notification)
        have_count(0).matches?(
          browser_root.locator(".notification a[href='#{notification.url}']").filter(visible: true),
        )
      end

      def has_notification_count_of?(count)
        have_count(count).matches?(browser_root.locator(".notification").filter(visible: true))
      end
    end
  end
end
