# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminColorPalettesConfigArea < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/colors")
      end

      def palette(id)
        find(".color-palettes-list li[data-palette-id=\"#{id}\"]")
      end

      def open_palette(color_scheme)
        find("a[href='/admin/config/colors/#{color_scheme.id}']", text: color_scheme.name).click
        self
      end

      def create_button
        find(".create-new-palette")
      end
    end
  end
end
