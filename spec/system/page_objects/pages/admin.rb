# frozen_string_literal: true

module PageObjects
  module Pages
    class Admin < PageObjects::Pages::Base
      def visit_filtered_plugin_setting(filter)
        visit("/admin/site_settings/category/plugins?filter=#{filter}")
        self
      end

      def toggle_setting(text)
        find('.admin-detail .setting-value span', text: text).click
        find('.admin-detail .setting-controls button.ok').click
        self
      end
    end
  end
end
