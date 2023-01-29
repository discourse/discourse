# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSettings < PageObjects::Pages::Base
      def visit_filtered_plugin_setting(filter)
        visit("/admin/site_settings/category/plugins?filter=#{filter}")
        self
      end

      def toggle_setting(setting_name, text = "")
        setting = find(".admin-detail .row.setting[data-setting='#{setting_name}']")
        setting.find(".setting-value span", text: text).click
        setting.find(".setting-controls button.ok").click
      end
    end
  end
end
