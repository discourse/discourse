# frozen_string_literal: true

module PageObjects
  module Components
    class InterfaceColorSelector < PageObjects::Components::Base
      attr_reader :container_selector

      SELECTOR = ".interface-color-selector"
      TRIGGER_SELECTOR = ".interface-color-selector-trigger"
      CONTENT_SELECTOR = ".interface-color-selector-content"

      def initialize(container_selector)
        @container_selector = container_selector
      end

      def available?
        find(container_selector).has_css?(TRIGGER_SELECTOR)
      end

      def not_available?
        find(container_selector).has_no_css?(TRIGGER_SELECTOR)
      end

      def expand
        # Ensure the menu is closed before we try to expand it.
        # This prevents flakiness if the menu is still closing from a previous action.
        page.has_no_css?(CONTENT_SELECTOR)

        find(container_selector).find(TRIGGER_SELECTOR).click
        find(CONTENT_SELECTOR)
      end

      def has_light_as_current_mode?
        has_css?(TRIGGER_SELECTOR + "[data-current-mode='light']")
      end

      def has_dark_as_current_mode?
        has_css?(TRIGGER_SELECTOR + "[data-current-mode='dark']")
      end

      def has_auto_as_current_mode?
        has_css?(TRIGGER_SELECTOR + "[data-current-mode='auto']")
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
