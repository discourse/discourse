# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferences < PageObjects::Pages::Base
      def visit(user)
        page.visit("/u/#{user.username}/preferences")
        self
      end

      def click_interface_tab
        click_link "Interface"
        self
      end

      def click_secondary_navigation_menu_scroll_right
        find(".horizontal-overflow-nav__scroll-right").click
      end

      def click_secondary_navigation_menu_scroll_left
        find(".horizontal-overflow-nav__scroll-left").click
      end

      INTERFACE_LINK_CSS_SELECTOR = ".user-nav__preferences-tracking"

      def has_interface_link_visible?
        horizontal_secondary_link_visible?(INTERFACE_LINK_CSS_SELECTOR, visible: true)
      end

      def has_interface_link_not_visible?
        horizontal_secondary_link_visible?(INTERFACE_LINK_CSS_SELECTOR, visible: false)
      end

      ACCOUNT_LINK_CSS_SELECTOR = ".user-nav__preferences-account"

      def has_account_link_visible?
        horizontal_secondary_link_visible?(ACCOUNT_LINK_CSS_SELECTOR, visible: true)
      end

      def has_account_link_not_visible?
        horizontal_secondary_link_visible?(ACCOUNT_LINK_CSS_SELECTOR, visible: false)
      end

      def has_primary_email?(email)
        has_css?(".email-first", text: email)
      end

      private

      def horizontal_secondary_link_visible?(selector, visible: true)
        within(".user-navigation-secondary") { page.has_selector?(selector, visible: visible) }
      end
    end
  end
end
