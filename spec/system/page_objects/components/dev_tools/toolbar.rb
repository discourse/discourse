# frozen_string_literal: true

module PageObjects
  module Components
    module DevTools
      class Toolbar < PageObjects::Components::Base
        def enable
          browser_page.then { |pw| pw.evaluate("window.enableDevTools()") }
          has_toolbar? # Wait for toolbar to appear
          self
        end

        def disable
          browser_root.locator(".dev-tools-toolbar .disable-dev-tools").filter(visible: true).click
          self
        end

        def toggle_plugin_outlets
          browser_root
            .locator(".dev-tools-toolbar .toggle-plugin-outlets")
            .filter(visible: true)
            .click
          self
        end

        def open_upcoming_changes_menu
          browser_root
            .locator(".dev-tools-toolbar .toggle-upcoming-changes-menu")
            .filter(visible: true)
            .click
          self
        end

        def close_upcoming_changes_menu
          if has_upcoming_changes_menu?
            browser_root
              .locator(".dev-tools-toolbar .toggle-upcoming-changes-menu")
              .filter(visible: true)
              .click
          end

          self
        end

        def has_upcoming_changes_menu?
          have_count(0).does_not_match?(
            browser_root.locator(".upcoming-changes-debug-menu").filter(visible: true),
          )
        end

        def has_no_upcoming_changes_menu?
          have_count(0).matches?(
            browser_root.locator(".upcoming-changes-debug-menu").filter(visible: true),
          )
        end

        def toggle_upcoming_changes_menu_item(item_name)
          browser_root
            .locator(".upcoming-changes-debug-menu label")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(item_name))
            .click
          self
        end

        def upcoming_change_site_setting_value(site_setting_name)
          browser_page.evaluate(
            "function(arguments) { return #{"Discourse.__container__.lookup('service:site-settings').#{site_setting_name}"} }",
            arg: [],
          )
        end

        def open_blocks_menu
          browser_root.locator(".dev-tools-toolbar .toggle-blocks").filter(visible: true).click
          self
        end

        def close_blocks_menu
          if have_count(0).does_not_match?(
               browser_root.locator(".block-debug-menu").filter(visible: true),
             )
            browser_root.locator(".dev-tools-toolbar .toggle-blocks").filter(visible: true).click
          end
          self
        end

        def toggle_block_visual_overlay
          open_blocks_menu
          browser_root
            .locator(".block-debug-menu label")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern("Visual overlay"))
            .click
          close_blocks_menu
          self
        end

        def toggle_ghost_blocks
          open_blocks_menu
          browser_root
            .locator(".block-debug-menu label")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern("Ghost blocks"))
            .click
          close_blocks_menu
          self
        end

        def toggle_block_outlet_boundaries
          open_blocks_menu
          browser_root
            .locator(".block-debug-menu label")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern("Outlet boundaries"))
            .click
          close_blocks_menu
          self
        end

        def has_toolbar?
          have_count(0).does_not_match?(
            browser_root.locator(".dev-tools-toolbar").filter(visible: true),
          )
        end

        def has_no_toolbar?
          have_count(0).matches?(browser_root.locator(".dev-tools-toolbar").filter(visible: true))
        end
      end
    end
  end
end
