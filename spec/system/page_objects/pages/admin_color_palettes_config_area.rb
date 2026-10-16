# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminColorPalettesConfigArea < PageObjects::Pages::Base
      def visit
        browser_page
          .goto("/admin/config/colors")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def palette(id)
        browser_root.locator(".color-palettes-list li[data-palette-id=\"#{id}\"]").filter(
          visible: true,
        )
      end

      def create_button
        browser_root.locator(".create-new-palette").filter(visible: true)
      end
    end
  end
end
