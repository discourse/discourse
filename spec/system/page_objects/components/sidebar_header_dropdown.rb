# frozen_string_literal: true

module PageObjects
  module Components
    class SidebarHeaderDropdown < PageObjects::Components::Base
      def click
        browser_root.locator(".hamburger-dropdown").filter(visible: true).click
        wait_for_animation(browser_root.locator(".menu-panel").filter(visible: true), timeout: 5)
        self
      end

      SIDEBAR_HAMBURGER_DROPDOWN = ".sidebar-hamburger-dropdown"

      def visible?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(SIDEBAR_HAMBURGER_DROPDOWN).filter(visible: true),
        )
      end

      def hidden?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(SIDEBAR_HAMBURGER_DROPDOWN).filter(visible: true),
        )
      end

      def has_no_keyboard_shortcuts_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".sidebar-footer-actions-keyboard-shortcuts").filter(visible: true),
        )
      end

      def click_categories_header_button
        browser_root
          .locator("[data-section-name='categories'] .sidebar-section-header-button")
          .filter(visible: true)
          .click
      end

      def click_topics_link
        browser_root
          .locator(".sidebar-section-link[data-link-name='everything']")
          .filter(visible: true)
          .click
      end

      def click_outside
        width =
          browser_page.evaluate("function(arguments) { return document.body.clientWidth }", arg: [])
        browser_root.locator("body").filter(visible: true).click(position: { x: width - 1, y: 1 })
      end
    end
  end
end
