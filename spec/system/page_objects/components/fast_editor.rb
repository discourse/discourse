# frozen_string_literal: true

module PageObjects
  module Components
    class FastEditor < PageObjects::Components::Base
      def fill_content(content)
        fast_edit_input.fill(content)
        self
      end

      def clear_content
        fill_content("")
      end

      def has_displayed_content?(content)
        fast_edit_input.input_value == content
      end

      def save
        browser_root.locator(".save-fast-edit").filter(visible: true).click
      end

      def fast_edit_input
        browser_root.locator("#fast-edit-input").filter(visible: true)
      end
    end
  end
end
