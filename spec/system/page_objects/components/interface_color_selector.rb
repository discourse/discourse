# frozen_string_literal: true

module PageObjects
  module Components
    class InterfaceColorSelector < PageObjects::Components::Base
      attr_reader :container_selector

      SELECTOR = ".interface-color-selector"

      def initialize(container_selector)
        @container_selector = container_selector
      end

      def available?
        find(container_selector).has_css?(SELECTOR)
      end

      def not_available?
        find(container_selector).has_no_css?(SELECTOR)
      end

      def expand
        find(container_selector).find(SELECTOR).click
      end

      def has_light_as_current_mode?
        has_css?(SELECTOR + "[data-current-mode='light']")
      end

      def has_dark_as_current_mode?
        has_css?(SELECTOR + "[data-current-mode='dark']")
      end

      def has_auto_as_current_mode?
        has_css?(SELECTOR + "[data-current-mode='auto']")
      end

      def light_option
        find("#{SELECTOR}__light-option")
      end

      def dark_option
        find("#{SELECTOR}__dark-option")
      end

      def auto_option
        find("#{SELECTOR}__auto-option")
      end
    end
  end
end
