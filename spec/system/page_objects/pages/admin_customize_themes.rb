# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomizeThemes < PageObjects::Pages::Base
      def has_inactive_themes?
        has_css?(".inactive-indicator")
      end

      def has_no_inactive_themes?
        has_no_css?(".inactive-indicator")
      end

      def has_select_inactive_mode_button?
        has_css?(".select-inactive-mode")
      end

      def has_overridden_setting?(setting_name)
        has_css?(setting_selector(setting_name, overridden: true))
      end

      def has_no_overriden_setting?(setting_name)
        has_no_css?(setting_selector(setting_name, overridden: true))
      end

      def has_setting_description?(setting_name, description)
        has_css?("#{setting_selector(setting_name)} .desc", exact_text: description)
      end

      def reset_overridden_setting(setting_name)
        setting_section = find("section.theme.settings .setting[data-setting=\"#{setting_name}\"]")
        setting_section.click_button(I18n.t("admin_js.admin.settings.reset"))
        setting_section.find(".setting-controls .ok").click
      end

      def click_select_inactive_mode
        find(".select-inactive-mode").click
      end

      def cancel_select_inactive_mode
        find(".cancel-select-inactive-mode").click
      end

      def has_inactive_themes_selected?(count:)
        has_css?(".inactive-theme input:checked", count: count)
      end

      def has_themes?(count:)
        has_css?(".themes-list-container__item", count: count)
      end

      def toggle_all_inactive
        find(".toggle-all-inactive").click
      end

      def has_disabled_delete_theme_button?
        find_button("Delete", disabled: true)
      end

      def click_delete_themes_button
        find(".btn-delete").click
      end

      def click_edit_objects_theme_setting_button(setting_name)
        find(".theme-setting[data-setting=\"#{setting_name}\"] .setting-value-edit-button").click
        PageObjects::Pages::AdminObjectsThemeSettingEditor.new
      end

      def click_theme_settings_editor_button
        click_button(I18n.t("admin_js.admin.customize.theme.settings_editor"))
        PageObjects::Components::AdminThemeSettingsEditor.new
      end

      def switch_to_components
        find(".components-tab").click
      end

      def switch_to_themes
        find(".themes-tab").click
      end

      def search(term)
        find(".themes-list-search__input").fill_in with: term
      end

      def has_no_search?
        has_no_css?(".themes-list-search__input")
      end

      private

      def setting_selector(setting_name, overridden: false)
        "section.theme.settings .setting#{overridden ? ".overridden" : ""}[data-setting=\"#{setting_name}\"]"
      end
    end
  end
end
