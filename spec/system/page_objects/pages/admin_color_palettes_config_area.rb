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

      def create_button
        find(".create-new-palette")
      end
    end
  end
end
