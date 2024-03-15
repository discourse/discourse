# frozen_string_literal: true

module PageObjects
  module Components
    class ThemeTranslationPicker < PageObjects::Components::Base
      def type_input(content)
        picker.send_keys(content)
        self
      end

      def fill_input(content)
        picker.fill_in(with: content)
        self
      end

      def clear_input
        fill_input("")
      end

      def picker
        find(".translation-selector-container summary").click
        find(".translation-selector-container input")
      end
    end
  end
end
