# frozen_string_literal: true

module PageObjects
  module Components
    class ThemeTranslationTextArea < PageObjects::Components::Base
      def type_input(content)
        editor_input.press_sequentially(content)
        self
      end

      def fill_input(content)
        editor_input.fill(content)
        self
      end

      def clear_input
        fill_input("")
      end

      def editor_input
        browser_root.locator(".theme.translations .row:nth-child(1) textarea").filter(visible: true)
      end

      def get_input
        editor_input.input_value
      end
    end
  end
end
