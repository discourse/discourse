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

        def open_upcoming_changes_menu
          find(".dev-tools-toolbar .toggle-upcoming-changes-menu").click
          self
        end

        def close_upcoming_changes_menu
          if has_upcoming_changes_menu?
            find(".dev-tools-toolbar .toggle-upcoming-changes-menu").click
          end

          self
        end

        def has_upcoming_changes_menu?
          page.has_css?(".upcoming-changes-debug-menu")
        end

        def has_no_upcoming_changes_menu?
          page.has_no_css?(".upcoming-changes-debug-menu")
        end

        def toggle_upcoming_changes_menu_item(item_name)
          find(".upcoming-changes-debug-menu label", text: item_name).click
          self
        end

        def upcoming_change_site_setting_value(site_setting_name)
          page.evaluate_script(
            "Discourse.__container__.lookup('service:site-settings').#{site_setting_name}",
          )
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
