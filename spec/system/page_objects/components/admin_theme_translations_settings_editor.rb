# frozen_string_literal: true

module PageObjects
  module Components
    class AdminThemeTranslationsSettingsEditor < Base
      def fill_in(translation)
        editor.fill_input(translation)
        self
      end

      def save
        find(".btn.no-text.btn-icon.ok").click
        self
      end

      def get_input_value
        editor.get_input
      end

      private

      def editor
        @editor ||= ThemeTranslationTextArea.new
      end
    end
  end
end
