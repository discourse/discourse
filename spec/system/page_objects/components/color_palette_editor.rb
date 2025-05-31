# frozen_string_literal: true

module PageObjects
  module Components
    class ColorPaletteEditor < PageObjects::Components::Base
      attr_reader :component

      def initialize(component)
        @component = component
      end

      def has_light_tab_active?
        component.has_css?(".light-tab.active")
      end

      def has_dark_tab_active?
        component.has_css?(".dark-tab.active")
      end

      def switch_to_light_tab
        component.find(".light-tab").click
      end

      def switch_to_dark_tab
        component.find(".dark-tab").click
      end

      def input_for_color(name)
        component.find(
          ".color-palette-editor__colors-item[data-color-name=\"#{name}\"] input[type=\"color\"]",
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
