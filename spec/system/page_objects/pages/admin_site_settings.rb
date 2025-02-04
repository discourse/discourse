# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSiteSettings < PageObjects::Pages::Base
      def visit_filtered_plugin_setting(filter)
        page.visit("/admin/site_settings/category/plugins?filter=#{filter}")
        self
      end

      def visit(filter = nil)
        if filter.present?
          page.visit("/admin/site_settings?filter=#{filter}")
        else
          page.visit("/admin/site_settings")
        end
        self
      end

      def visit_category(category)
        page.visit("/admin/site_settings/category/#{category}")
        self
      end

      def setting_row_selector(setting_name)
        ".row.setting[data-setting='#{setting_name}']"
      end

      def has_setting?(setting_name)
        has_css?(".row.setting[data-setting=\"#{setting_name}\"]")
      end

      def find_setting(setting_name, overridden: false)
        find(
          ".admin-detail #{setting_row_selector(setting_name)}#{overridden ? ".overridden" : ""}",
        )
      end

      def toggle_setting(setting_name, text = "")
        setting = find_setting(setting_name)
        setting.find(".setting-value span", text: text).click
        save_setting(setting)
      end

      def change_number_setting(setting_name, value, save_changes = true)
        setting = find_setting(setting_name)
        setting.fill_in(with: value)
        save_setting(setting) if save_changes
      end

      def select_from_emoji_list(setting_name, text = "", save_changes = true)
        setting = find(".admin-detail .row.setting[data-setting='#{setting_name}']")
        setting.find(".setting-value .value-list > .value button").click
        setting.find(".setting-value .emoji-picker .emoji[title='#{text}']").click
        save_setting(setting) if save_changes
      end

      def save_setting(setting_element)
        setting_element.find(".setting-controls button.ok").click
      end

      def has_overridden_setting?(setting_name, value: nil)
        setting_field = find_setting(setting_name, overridden: true)
        return setting_field.find(".setting-value input").value == value.to_s if value
        true
      end

      def has_no_overridden_setting?(setting_name)
        find_setting(setting_name, overridden: false)
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

      def clear_search
        find("#setting-filter").click
        self
      end

      def toggle_only_show_overridden
        find("#setting-filter-toggle-overridden").click
        self
      end

      def has_search_result?(setting)
        has_css?("div[data-setting='#{setting}']")
      end

      def has_n_results?(count)
        has_css?(".admin-detail .row.setting", count: count)
      end

      def has_greater_than_n_results?(count)
        assert_selector(".admin-detail .row.setting", minimum: count)
      end
    end
  end
end
