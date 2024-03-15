# frozen_string_literal: true

module PageObjects
  module Components
    class AdminThemeTranslationsPicker < Base
      def fill_in(locale)
        picker.fill_input(locale)
        self
      end

      def save
        find(".select-kit-row").click
        self
      end

      private

      def picker
        @picker ||= ThemeTranslationPicker.new
      end
    end
  end
end
