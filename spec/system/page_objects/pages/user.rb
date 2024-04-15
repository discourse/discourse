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

      def has_primary_navigation_item?(name)
        page.has_css?(primary_navigation_selector(name))
      end

      def has_no_primary_navigation_item?(name)
        page.has_no_css?(primary_navigation_selector(name))
      end

      def has_secondary_navigation_item?(name)
        page.has_css?(secondary_navigation_selector(name))
      end

      def has_no_secondary_navigation_item?(name)
        page.has_no_css?(secondary_navigation_selector(name))
      end

      def click_staff_info_warnings_link(user, warnings_count: 0)
        staff_counters = page.find(".staff-counters")
        staff_counters.find("a[href='/u/#{user.username}/messages/warnings']").click
        self
      end

      def expand_info_panel
        button = page.find("button[aria-controls='collapsed-info-panel']")
        button.click if button["aria-expanded"] == "false"
        self
      end

      def click_primary_navigation_item(name)
        page.find(primary_navigation_selector(name)).click
      end

      private

      def primary_navigation_selector(name)
        ".new-user-wrapper .user-navigation-primary li.user-nav__#{name}"
      end

      def secondary_navigation_selector(name)
        ".new-user-wrapper .user-navigation-secondary li.user-nav__#{name}"
      end
    end
  end
end
