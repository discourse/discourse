# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSettings < PageObjects::Pages::Base
      def visit_filtered_plugin_setting(filter)
        page.visit("/admin/site_settings/category/plugins?filter=#{filter}")
        self
      end

      def visit
        page.visit("/admin/site_settings")
        self
      end

      def visit_category(category)
        page.visit("/admin/site_settings/category/#{category}")
        self
      end

      def toggle_setting(setting_name, text = "")
        setting = find(".admin-detail .row.setting[data-setting='#{setting_name}']")
        setting.find(".setting-value span", text: text).click
        setting.find(".setting-controls button.ok").click
      end

      def select_from_emoji_list(setting_name, text = "", save_changes = true)
        setting = find(".admin-detail .row.setting[data-setting='#{setting_name}']")
        setting.find(".setting-value .value-list > .value button").click
        setting.find(".setting-value .emoji-picker .emoji[title='#{text}']").click
        setting.find(".setting-controls button.ok").click if save_changes
      end

      def values_in_list(setting_name)
        vals = []
        setting = find(".admin-detail .row.setting[data-setting='#{setting_name}']")
        setting
          .all(:css, ".setting-value .values .value .value-input span")
          .map { |e| vals << e.text }
        vals
      end

      def type_in_search(input)
        find("input#setting-filter").send_keys(input)
        self
      end

      def has_search_result?(setting)
        page.has_selector?("div[data-setting='#{setting}']")
      end
    end
  end
end
