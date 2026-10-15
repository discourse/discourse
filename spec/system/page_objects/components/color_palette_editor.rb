# frozen_string_literal: true

module PageObjects
  module Components
    class ColorPaletteEditor < PageObjects::Components::Base
      attr_reader :component

      def initialize(component)
        @component = component
      end

      def input_for_color(name)
        component.locator(
          ".color-palette-editor__colors-item[data-color-name=\"#{name}\"] input[type=\"color\"]",
        ).filter(visible: true)
      end

      def input_for_hex(name)
        component.locator(
          ".color-palette-editor__colors-item[data-color-name=\"#{name}\"] input[type=\"text\"]",
        ).filter(visible: true)
      end

      def get_color_value(name)
        input_for_color(name).input_value
      end

      def change_color(name, hex)
        hex = "##{hex}" if !hex.start_with?("#")
        input_for_color(name).fill(hex)
      end

      def has_revert_button_for_color?(name)
        PlaywrightMatchers.have_count(0).does_not_match?(
          component.locator(
            ".color-palette-editor__colors-item[data-color-name='#{name}'] .color-palette-editor__revert:not(.--hidden)",
          ).filter(visible: true),
        )
      end

      def has_no_revert_button_for_color?(name)
        PlaywrightMatchers.have_count(0).matches?(
          component.locator(
            ".color-palette-editor__colors-item[data-color-name='#{name}'] .color-palette-editor__revert:not(.--hidden)",
          ).filter(visible: true),
        )
      end

      def revert_button_for_color(name)
        component.locator(
          ".color-palette-editor__colors-item[data-color-name='#{name}'] .color-palette-editor__revert",
        ).filter(visible: true)
      end
    end
  end
end
