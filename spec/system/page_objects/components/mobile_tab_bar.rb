# frozen_string_literal: true

module PageObjects
  module Components
    class MobileTabBar < PageObjects::Components::Base
      SELECTOR = ".mobile-tab-bar"

      def click_tab(key)
        find("#{SELECTOR} .mobile-tab-bar__tab[data-key='#{key}']").click
        self
      end

      def open_profile_menu
        find(".header-profile-toggle button").click
        self
      end

      def open_section_menu
        find(".header-section-nav button").click
        self
      end

      def has_tabs?(*keys)
        all("#{SELECTOR} .mobile-tab-bar__tab").map { |tab| tab["data-key"] } == keys
      end

      def has_active_tab?(key)
        has_css?("#{SELECTOR} .mobile-tab-bar__tab.--active[data-key='#{key}']")
      end

      def visible?
        has_css?(SELECTOR)
      end

      def hidden?
        has_no_css?(SELECTOR)
      end
    end
  end
end
