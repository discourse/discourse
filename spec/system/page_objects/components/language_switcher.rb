# frozen_string_literal: true

module PageObjects
  module Components
    class LanguageSwitcher < PageObjects::Components::Base
      SELECTOR = "button[data-identifier='language-switcher']"

      def initialize
        @menu = PageObjects::Components::DMenu.new(SELECTOR)
      end

      def visible?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(SELECTOR).filter(visible: true),
        )
      end

      def not_visible?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(SELECTOR).filter(visible: true),
        )
      end

      def select_language(locale)
        @menu.expand
        browser_page.expect_navigation(waitUntil: "load") do
          @menu.option("[data-menu-option-id='#{locale}']").click
        end
        SystemBrowserBootstrap.wait_for(browser_page)
      end
    end
  end
end
