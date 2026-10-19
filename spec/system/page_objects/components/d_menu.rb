# frozen_string_literal: true

module PageObjects
  module Components
    class DMenu < PageObjects::Components::Base
      attr_reader :component

      def initialize(trigger_input, identifier = nil)
        if trigger_input.is_a?(Playwright::Locator)
          @component = trigger_input
        else
          @component = browser_root.locator(trigger_input).filter(visible: true)
        end

        @identifier = identifier
      end

      def expand
        raise "DMenu is already expanded" if is_expanded?
        component.click.tap { expect(component).to have_attribute("aria-expanded", "true") }
      end

      def collapse
        raise "DMenu is already collapsed" if is_collapsed?
        component.click.tap { expect(component).to have_attribute("aria-expanded", "false") }
      end

      def is_expanded?
        component.get_attribute("aria-expanded") == "true"
      end

      def is_collapsed?
        !is_expanded?
      end

      def portal_with_identifier_selector
        if @identifier.nil?
          "#d-menu-portals"
        else
          "[data-content][data-identifier=\"#{@identifier}\"]"
        end
      end

      def remove_selected_option(title)
        browser_root
          .locator(".d-multi-select-trigger__selected-item")
          .filter(visible: true)
          .filter(hasText: title)
          .click
      end

      def option(selector, match = nil)
        result =
          browser_root
            .locator(portal_with_identifier_selector)
            .locator(selector)
            .filter(visible: true)
        match == :first ? result.first : result
      end

      def has_option?(selector, text = nil)
        result = option(selector)
        result = result.filter(hasText: text) if text
        have_count(0).does_not_match?(result)
      end

      def has_no_option?(selector)
        within_browser(portal_with_identifier_selector, wait_state: "attached") do
          have_count(0).matches?(browser_root.locator(selector).filter(visible: true))
        end
      end

      def has_value?(value)
        contain_text(value, useInnerText: true).matches?(component)
      end
    end
  end
end
