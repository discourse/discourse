# frozen_string_literal: true

module PageObjects
  module Pages
    class Header < PageObjects::Pages::Base
      def get_computed_style_value(selector, property)
        page.evaluate_script(
          "window.getComputedStyle(document.querySelector('#{selector}')).getPropertyValue('#{property}')",
        ).strip
      end

      def resize_element(selector, size)
        page.evaluate_script("document.querySelector('#{selector}').style.height = '#{size}px'")
      end

      def active_element_id
        current_active_element[:id]
      end

      def click_outside
        find(".d-modal").click(x: 0, y: 0)
      end
    end
  end
end
