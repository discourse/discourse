# frozen_string_literal: true

module PageObjects
  module Components
    class ThemeTranslationTextArea < PageObjects::Components::Base
      def type_input(content)
        editor_input.send_keys(content)
        self
      end

      def fill_input(content)
        editor_input.fill_in(with: content)
        self
      end

      def clear_input
        fill_input("")
      end

      def editor_input
        find(".theme.translations .row:nth-child(1) textarea")
      end

      def get_input
        editor_input.value
      end
    end
  end
end
