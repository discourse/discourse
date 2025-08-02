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

      def find_notification(notification)
        find(".notification a[href='#{notification.url}']")
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

      def has_notification_count_of?(count)
        page.has_css?(".notification", count: count)
      end
    end
  end
end
