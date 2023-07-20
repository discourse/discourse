# frozen_string_literal: true

module PageObjects
  module Pages
    class User < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}")
        self
      end

      def find(selector)
        page.find(".new-user-wrapper #{selector}")
      end

      def active_user_primary_navigation
        find(".user-navigation-primary li a.active")
      end

      def active_user_secondary_navigation
        find(".user-navigation-secondary li a.active")
      end

      def has_warning_messages_path?(user)
        page.has_current_path?("/u/#{user.username}/messages/warnings")
      end

      def click_staff_info_warnings_link(user, warnings_count: 0)
        staff_counters = page.find(".staff-counters")
        staff_counters.find("a[href='/u/#{user.username}/messages/warnings']").click
        self
      end
    end
  end
end
