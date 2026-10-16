# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferences < PageObjects::Pages::Base
      def visit(user)
        browser_page
          .goto("/u/#{user.username}/preferences")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def click_interface_tab
        browser_root
          .locator("[id=#{"Interface".to_s.to_json}], [name=#{"Interface".to_s.to_json}]")
          .or(browser_root.get_by_role("link", name: "Interface"))
          .filter(visible: true)
          .click
        self
      end

      def click_secondary_navigation_menu_scroll_right
        browser_root.locator(".horizontal-overflow-nav__scroll-right").filter(visible: true).click
      end

      def click_secondary_navigation_menu_scroll_left
        browser_root.locator(".horizontal-overflow-nav__scroll-left").filter(visible: true).click
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
        contain_text([browser_text_pattern(email)], useInnerText: true).matches?(
          browser_root.locator(".email-first").filter(visible: true),
        )
      end

      private

      def horizontal_secondary_link_visible?(selector, visible: true)
        within_browser(browser_root.locator(".user-navigation-secondary").filter(visible: true)) do
          links = browser_root.locator(selector)
          links = links.filter(visible: true) if visible
          have_count(0).does_not_match?(links)
        end
      end
    end
  end
end
