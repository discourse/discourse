# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminPluginsList < PageObjects::Pages::Base
      def visit
        page.visit("/admin/plugins")
        self
      end

      def find_plugin(plugin)
        find(".admin-plugins-list tr[data-plugin-name=\"#{plugin}\"]")
      end
    end
  end
end
