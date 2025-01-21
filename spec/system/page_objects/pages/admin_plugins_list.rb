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

      def has_plugin_tab?(plugin)
        page.has_css?(plugin_nav_tab_selector(plugin))
      end

      def plugin_nav_tab_selector(plugin)
        ".d-nav-submenu__tabs .admin-plugin-tab-nav-item[data-plugin-nav-tab-id=\"#{plugin}\"]"
      end
    end
  end
end
