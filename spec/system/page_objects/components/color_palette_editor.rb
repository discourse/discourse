# frozen_string_literal: true

module PageObjects
  module Components
    class ColorPaletteEditor < PageObjects::Components::Base
      attr_reader :component

      def initialize(component)
        @component = component
      end

      def input_for_color(name)
        component.find(
          ".color-palette-editor__colors-item[data-color-name=\"#{name}\"] input[type=\"color\"]",
        )
      end

      def input_for_hex(name)
        component.find(
          ".color-palette-editor__colors-item[data-color-name=\"#{name}\"] input[type=\"text\"]",
        )
      end

      def get_color_value(name)
        input_for_color(name).value
      end

      def change_color(name, hex)
        hex = "##{hex}" if !hex.start_with?("#")
        input_for_color(name).fill_in(with: hex)
      end

      def has_revert_button_for_color?(name)
        component.has_css?(
          ".color-palette-editor__colors-item[data-color-name='#{name}'] .color-palette-editor__revert:not(.--hidden)",
        )
      end

      def has_no_revert_button_for_color?(name)
        component.has_no_css?(
          ".color-palette-editor__colors-item[data-color-name='#{name}'] .color-palette-editor__revert:not(.--hidden)",
        )
      end

      def revert_button_for_color(name)
        component.find(
          ".color-palette-editor__colors-item[data-color-name='#{name}'] .color-palette-editor__revert",
        )
      end
    end
  end
end
