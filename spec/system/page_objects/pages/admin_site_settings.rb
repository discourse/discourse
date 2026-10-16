# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminSiteSettings < PageObjects::Pages::Base
      def visit_filtered_plugin_setting(filter)
        browser_page
          .goto("/admin/site_settings/category/plugins?filter=#{filter}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit(filter = nil)
        if filter.present?
          browser_page
            .goto("/admin/site_settings?filter=#{filter}")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        else
          browser_page
            .goto("/admin/site_settings")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        end
        self
      end

      def visit_category(category)
        browser_page
          .goto("/admin/site_settings/category/#{category}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def navigate_to_category(category)
        browser_root.locator("a.#{category}").filter(visible: true).click
        self
      end

      def setting_row_selector(setting_name)
        ".row.setting[data-setting='#{setting_name}']"
      end

      def select_list_values(setting_name, values)
        setting =
          PageObjects::Components::SelectKit.new(
            ".row.setting[data-setting='#{setting_name}'] .list-setting",
          )
        setting.expand
        values.each { |value| setting.select_row_by_value(value) }
        self
      end

      def select_enum_value(setting_name, value)
        enum_setting(setting_name).select(value)
        self
      end

      def enum_setting(setting_name)
        PageObjects::Components::FormKitField.new(
          find_setting(setting_name).locator("[data-name='#{setting_name}']").filter(visible: true),
        )
      end

      def has_enum_value?(setting_name, value, text: nil)
        contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(
            "#{setting_row_selector(setting_name)} select option[value='#{value}']:checked",
          ),
        )
      end

      def has_setting?(setting_name)
        have_count(0).does_not_match?(
          browser_root.locator(".row.setting[data-setting=\"#{setting_name}\"]").filter(
            visible: true,
          ),
        )
      end

      def find_setting(setting_name, overridden: false)
        browser_root.locator(
          ".admin-detail #{setting_row_selector(setting_name)}#{overridden ? ".overridden" : ""}",
        ).filter(visible: true)
      end

      def fill_setting(setting_name, value)
        setting = find_setting(setting_name)
        setting.locator("input:not([type=hidden]), textarea").filter(visible: true).fill(value.to_s)
      end

      def toggle_setting(setting_name, text = "")
        setting = find_setting(setting_name)
        setting
          .locator(".setting-value span")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(text))
          .click
        save_setting(setting)
      end

      def toggle_bool_setting(setting_name)
        setting = find_setting(setting_name)
        PageObjects::Components::FormKitField.new(
          setting.locator(".form-kit__field").filter(visible: true),
        ).toggle
        save_setting(setting)
      end

      def bool_setting_checkbox(setting_name)
        find_setting(setting_name).locator(".setting-value input[type=checkbox]")
      end

      def secret_setting_input(setting_name)
        find_setting(setting_name).locator(".form-kit__control-password").filter(visible: true)
      end

      def reveal_secret_setting(setting_name)
        setting = find_setting(setting_name)
        PageObjects::Components::FormKitField.new(
          setting.locator(".form-kit__field").filter(visible: true),
        ).toggle
        self
      end

      def submit_setting_with_keyboard(setting_name, value)
        input = find_setting(setting_name).locator(".form-kit__field input").filter(visible: true)
        input.fill(value.to_s)
        input.press("Enter")
      end

      def change_number_setting(setting_name, value, save_changes = true)
        setting = find_setting(setting_name)
        setting.locator("input:not([type=hidden]), textarea").filter(visible: true).fill(value.to_s)
        save_setting(setting) if save_changes
      end

      def select_from_emoji_list(setting_name, text = "", save_changes = true)
        setting =
          browser_root.locator(".admin-detail .row.setting[data-setting='#{setting_name}']").filter(
            visible: true,
          )
        setting.locator(".setting-value .value-list > .value button").filter(visible: true).click
        browser_root.locator(".emoji-picker .emoji[title='#{text}']").filter(visible: true).click
        save_setting(setting) if save_changes
      end

      def save_setting(setting)
        setting = find_setting(setting) if setting.is_a?(String)
        setting.locator(".setting-controls button.ok").filter(visible: true).click
        self
      end

      def has_overridden_setting?(setting_name, value: nil)
        setting_field = find_setting(setting_name, overridden: true)
        if value
          return(
            setting_field.locator(".setting-value input").filter(visible: true).input_value ==
              value.to_s
          )
        end
        true
      end

      def has_overridden_topic_setting?(setting_name, value: nil)
        setting_field = find_setting(setting_name, overridden: true)
        if value
          return(
            setting_field
              .locator(".selected-name")
              .filter(visible: true)
              .get_attribute("data-value") == value.to_s
          )
        end
        true
      end

      def has_no_overridden_setting?(setting_name)
        find_setting(setting_name, overridden: false)
      end

      def values_in_list(setting_name)
        vals = []
        setting =
          browser_root.locator(".admin-detail .row.setting[data-setting='#{setting_name}']").filter(
            visible: true,
          )
        setting
          .locator(".setting-value .values .value .value-input span")
          .filter(visible: true)
          .all
          .map { |e| vals << e.inner_text.strip }
        vals
      end

      def type_in_search(input)
        browser_root.locator("input#setting-filter").filter(visible: true).press_sequentially(input)
        self
      end

      def clear_search
        browser_root.locator("#setting-filter").filter(visible: true).click
        self
      end

      def toggle_only_show_overridden
        browser_root.locator("#setting-filter-toggle-overridden").filter(visible: true).click
        self
      end

      def has_search_result?(setting)
        have_count(0).does_not_match?(
          browser_root.locator("div[data-setting='#{setting}']").filter(visible: true),
        )
      end

      def has_n_results?(count)
        have_count(count).matches?(
          browser_root.locator(".admin-detail .row.setting").filter(visible: true),
        )
      end

      def has_greater_than_n_results?(count)
        expect(
          browser_root.locator(".admin-detail .row.setting").filter(visible: true).nth(count - 1),
        ).to be_attached
      end

      def error_message(setting_name)
        setting = find_setting(setting_name)
        setting.locator(".setting-value .validation-error").filter(visible: true).inner_text.strip
      end

      def has_theme_warning?(setting_name, theme_name, theme_id)
        contain_text(browser_text_pattern(theme_name), useInnerText: true).matches?(
          find_setting(setting_name).locator(".setting-theme-warning__text").filter(visible: true),
        ) &&
          have_count(0).does_not_match?(
            find_setting(setting_name)
              .locator(".setting-theme-warning__text")
              .filter(visible: true)
              .get_by_role("link")
              .and(
                find_setting(setting_name)
                  .locator(".setting-theme-warning__text")
                  .filter(visible: true)
                  .locator("[href=#{"/admin/customize/themes/#{theme_id}".to_s.to_json}]"),
              )
              .filter(visible: true),
          )
      end

      def has_upcoming_change_default_warning?(setting_name, old_default:, new_default:)
        contain_text(
          browser_text_pattern(
            "The default for this setting has changed from #{old_default} to #{new_default}",
          ),
          useInnerText: true,
        ).matches?(
          find_setting(setting_name).locator(".setting-upcoming-change-warning__text").filter(
            visible: true,
          ),
        ) &&
          have_count(0).does_not_match?(
            find_setting(setting_name)
              .locator(".setting-upcoming-change-warning__text")
              .filter(visible: true)
              .get_by_role("link")
              .and(
                find_setting(setting_name)
                  .locator(".setting-upcoming-change-warning__text")
                  .filter(visible: true)
                  .locator(
                    "[href=#{"/admin/config/upcoming-changes?changeNamesFilter=enable_upload_debug_mode".to_s.to_json}]",
                  ),
              )
              .filter(visible: true),
          )
      end

      def has_disabled_input?(setting_name)
        have_count(0).does_not_match?(find_setting(setting_name).locator("input[disabled]"))
      end

      def has_visible_reorder_buttons?(setting_name)
        have_count(0).does_not_match?(
          browser_root.locator("#{setting_row_selector(setting_name)} .shift-up-value-btn").filter(
            visible: true,
          ),
        ) &&
          have_count(0).does_not_match?(
            browser_root.locator(
              "#{setting_row_selector(setting_name)} .shift-down-value-btn",
            ).filter(visible: true),
          )
      end

      def has_hidden_reorder_buttons?(setting_name)
        have_count(0).does_not_match?(
          browser_root.locator("#{setting_row_selector(setting_name)} .shift-up-value-btn").filter(
            visible: false,
          ),
        ) &&
          have_count(0).does_not_match?(
            browser_root.locator(
              "#{setting_row_selector(setting_name)} .shift-down-value-btn",
            ).filter(visible: false),
          )
      end

      # Methods for when the enable_new_reordering_controls upcoming change is
      # enabled. The two predicates above keep main's arrow-button behaviour.
      #
      # TODO (ui-kit-reorderable-list-cleanup) fold these over them once the
      # change ships.
      def has_reorder_handle?(setting_name)
        have_count(0).does_not_match?(
          browser_root.locator(
            "#{setting_row_selector(setting_name)} .d-reorderable-list__handle",
          ).filter(visible: true),
        )
      end

      def open_reorder_menu(setting_name)
        browser_root
          .locator("#{setting_row_selector(setting_name)} .d-reorderable-list__handle")
          .filter(visible: true)
          .first
          .click
        expect(
          browser_root.locator(".d-reorderable-list__move-item").filter(visible: true),
        ).not_to have_count(0)
        self
      end

      def move_list_value_to_top(setting_name, value)
        PageObjects::Components::ReorderableList.new(
          "#{setting_row_selector(setting_name)} .value[data-reorderable-key='#{value}']",
        ).move(:top)
        self
      end

      def has_list_values_in_order?(setting_name, values)
        list = "#{setting_row_selector(setting_name)} .values"
        have_count(values.size).matches?(
          browser_root.locator("#{list} .value").filter(visible: true),
        ) &&
          values.each_with_index.all? do |value, index|
            have_count(0).does_not_match?(
              browser_root.locator(
                "#{list} .value:nth-child(#{index + 1})[data-reorderable-key='#{value}']",
              ).filter(visible: true),
            )
          end
      end

      def category_setting(setting_name)
        PageObjects::Components::SelectKit.new(
          "#{setting_row_selector(setting_name)} .category-chooser",
        )
      end

      def group_setting(setting_name)
        PageObjects::Components::SelectKit.new("#{setting_row_selector(setting_name)} .combo-box")
      end

      def tag_list_setting(setting_name)
        PageObjects::Components::SelectKit.new("#{setting_row_selector(setting_name)} .tag-chooser")
      end

      def has_tags_in_setting?(setting_name, tags)
        tag_chooser = tag_list_setting(setting_name)
        tag_names = tags.map(&:name).sort
        selected_names = tag_chooser.value&.split(",")&.sort || []
        tag_names == selected_names
      end
    end
  end
end
