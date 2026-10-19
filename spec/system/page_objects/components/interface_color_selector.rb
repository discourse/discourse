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
        have_count(0).does_not_match?(
          browser_root
            .locator(container_selector)
            .filter(visible: true)
            .locator(TRIGGER_SELECTOR)
            .filter(visible: true),
        )
      end

      def not_available?
        have_count(0).matches?(
          browser_root
            .locator(container_selector)
            .filter(visible: true)
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(TRIGGER_SELECTOR)
            .filter(visible: true),
        )
      end

      def expand
        # Ensure the menu is closed before we try to expand it.
        # This prevents flakiness if the menu is still closing from a previous action.
        expect(browser_root.locator(CONTENT_SELECTOR).filter(visible: true)).to have_count(0)

        browser_root
          .locator(container_selector)
          .filter(visible: true)
          .locator(TRIGGER_SELECTOR)
          .filter(visible: true)
          .click
        browser_root.locator(CONTENT_SELECTOR).filter(visible: true)
      end

      def has_light_as_current_mode?
        have_count(0).does_not_match?(
          browser_root.locator(TRIGGER_SELECTOR + "[data-current-mode='light']").filter(
            visible: true,
          ),
        )
      end

      def has_dark_as_current_mode?
        have_count(0).does_not_match?(
          browser_root.locator(TRIGGER_SELECTOR + "[data-current-mode='dark']").filter(
            visible: true,
          ),
        )
      end

      def has_auto_as_current_mode?
        have_count(0).does_not_match?(
          browser_root.locator(TRIGGER_SELECTOR + "[data-current-mode='auto']").filter(
            visible: true,
          ),
        )
      end

      def light_option
        browser_root.locator("#{SELECTOR}__light-option").filter(visible: true)
      end

      def dark_option
        browser_root.locator("#{SELECTOR}__dark-option").filter(visible: true)
      end

      def auto_option
        browser_root.locator("#{SELECTOR}__auto-option").filter(visible: true)
      end
    end
  end
end
