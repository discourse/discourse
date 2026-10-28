# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminPluginsList < PageObjects::Pages::Base
      def visit
        page.visit("/admin/plugins")
        self
      end

      def find_plugin(plugin)
        find(plugin_row_selector(plugin))
      end

      def plugin_row_selector(plugin)
        ".admin-plugins-list .admin-plugins-list__row[data-plugin-name=\"#{plugin}\"]"
      end

      def click_plugin_name(plugin)
        find_plugin(plugin).find(".admin-plugins-list__name").click
      end

      def toggle_plugin(plugin)
        find(
          "#{plugin_row_selector(plugin)} .admin-plugins-list__enabled label.d-toggle-switch__label",
        ).click
      end

      def has_plugin_enabled?(plugin)
        has_css?(
          "#{plugin_row_selector(plugin)} .admin-plugins-list__enabled button[aria-checked='true']",
        )
      end

      def has_plugin_disabled?(plugin)
        has_css?(
          "#{plugin_row_selector(plugin)} .admin-plugins-list__enabled button[aria-checked='false']",
        )
      end
    end
  end
end
