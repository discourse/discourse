# frozen_string_literal: true

module PageObjects
  module Components
    class UserColorPaletteSelector < PageObjects::Components::Base
      def sidebar_footer_button_css
        ".sidebar-footer-actions .user-color-palette-selector"
      end

      def palette_menu
        PageObjects::Components::DMenu.new(find(sidebar_footer_button_css))
      end

      def open_palette_menu
        palette_menu.expand
      end

      def has_no_palette_menu?
        has_no_css?(".user-color-palette-selector-content")
      end

      def click_palette_menu_item(palette_name)
        find(
          ".user-color-palette-menu__content .user-color-palette-menu__item[data-color-palette='#{palette_name}']",
        ).click
      end

      def has_selected_palette?(palette)
        has_css?(
          ".user-color-palette-selector-trigger[data-selected-color-palette-id=\"#{palette.id}\"]",
        )
      end

      def has_loaded_css?
        has_css?(".user-color-palette-selector.user-color-palette-css-loaded")
      end

      def has_tertiary_color?(palette)
        computed_color_hex =
          page.evaluate_script(
            "getComputedStyle(document.documentElement).getPropertyValue('--tertiary')",
          )
        computed_color_hex == "#" + palette.colors.find { |color| color.name == "tertiary" }.hex
      end

      def has_computed_color?(color)
        computed_background_color =
          page.evaluate_script(
            "getComputedStyle(document.querySelector(\"li.sidebar-section-link-wrapper[data-list-item-name='everything'] .active\")).backgroundColor",
          )
        computed_background_color == color
      end
    end
  end
end
