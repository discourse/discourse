# frozen_string_literal: true

module PageObjects
  module Components
    module DevTools
      class Toolbar < PageObjects::Components::Base
        def enable
          page.driver.with_playwright_page { |pw| pw.evaluate("window.enableDevTools()") }
          has_toolbar? # Wait for toolbar to appear
          self
        end

        def disable
          find(".dev-tools-toolbar .disable-dev-tools").click
          self
        end

        def toggle_plugin_outlets
          find(".dev-tools-toolbar .toggle-plugin-outlets").click
          self
        end

        def open_blocks_menu
          find(".dev-tools-toolbar .toggle-blocks").click
          self
        end

        def close_blocks_menu
          find(".dev-tools-toolbar .toggle-blocks").click if page.has_css?(".block-debug-menu")
          self
        end

        def toggle_block_visual_overlay
          open_blocks_menu
          find(".block-debug-menu label", text: "Visual overlay").click
          close_blocks_menu
          self
        end

        def toggle_ghost_blocks
          open_blocks_menu
          find(".block-debug-menu label", text: "Ghost blocks").click
          close_blocks_menu
          self
        end

        def toggle_block_outlet_boundaries
          open_blocks_menu
          find(".block-debug-menu label", text: "Outlet boundaries").click
          close_blocks_menu
          self
        end

        def has_toolbar?
          page.has_css?(".dev-tools-toolbar")
        end

        def has_no_toolbar?
          page.has_no_css?(".dev-tools-toolbar")
        end
      end
    end
  end
end
