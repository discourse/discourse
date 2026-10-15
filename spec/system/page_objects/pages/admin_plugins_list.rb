# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminPluginsList < PageObjects::Pages::Base
      def visit
        browser_page.goto("/admin/plugins").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def find_plugin(plugin)
        browser_root.locator(plugin_row_selector(plugin)).filter(visible: true)
      end

      def plugin_row_selector(plugin)
        ".admin-plugins-list .admin-plugins-list__row[data-plugin-name=\"#{plugin}\"]"
      end

      def click_plugin_name(plugin)
        find_plugin(plugin).locator(".admin-plugins-list__name").filter(visible: true).click
      end

      def toggle_plugin(plugin)
        browser_root
          .locator(
            "#{plugin_row_selector(plugin)} .admin-plugins-list__enabled label.d-toggle-switch__label",
          )
          .filter(visible: true)
          .click
      end

      def has_plugin_enabled?(plugin)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{plugin_row_selector(plugin)} .admin-plugins-list__enabled button[aria-checked='true']",
          ).filter(visible: true),
        )
      end

      def has_plugin_disabled?(plugin)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{plugin_row_selector(plugin)} .admin-plugins-list__enabled button[aria-checked='false']",
          ).filter(visible: true),
        )
      end
    end
  end
end
