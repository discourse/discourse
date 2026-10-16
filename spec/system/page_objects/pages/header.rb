# frozen_string_literal: true

module PageObjects
  module Pages
    class Header < PageObjects::Pages::Base
      def get_computed_style_value(selector, property)
        browser_page.evaluate(
          "function(arguments) { return #{"window.getComputedStyle(document.querySelector('#{selector}')).getPropertyValue('#{property}')"} }",
          arg: [],
        ).strip
      end

      def resize_element(selector, size)
        browser_page.evaluate(
          "function(arguments) { return #{"document.querySelector('#{selector}').style.height = '#{size}px'"} }",
          arg: [],
        )
      end

      def active_element_id
        current_active_element[:id]
      end

      def click_outside
        browser_root.locator(".d-modal").filter(visible: true).click(position: { x: 0, y: 0 })
      end
    end
  end
end
