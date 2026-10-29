# frozen_string_literal: true

module PageObjects
  module Components
    class MobileTabBar < PageObjects::Components::Base
      SELECTOR = ".mobile-tab-bar"

      def click_tab(key)
        find("#{SELECTOR} .mobile-tab-bar__tab[data-key='#{key}']").click
        self
      end

      def open_menu
        find("#{SELECTOR} .mobile-tab-bar__menu").click
        self
      end

      def click_create
        find("#{SELECTOR} .mobile-tab-bar__create").click
        self
      end

      def click_create_action(label)
        find(".mobile-tab-bar__create-action", text: label).click
        self
      end

      def has_create_actions?(*labels)
        has_css?(".mobile-tab-bar__create-action", count: labels.size) &&
          all(".mobile-tab-bar__create-action").map(&:text) == labels
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
