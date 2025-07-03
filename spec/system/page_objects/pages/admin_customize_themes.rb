# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomizeThemes < PageObjects::Pages::AdminBase
      def visit(id)
        page.visit("/admin/customize/themes/#{id}")
      end

      def has_colors_tab?
        header.has_tab?("colors")
      end

      def has_colors_tab_active?
        header.has_active_tab?("colors")
      end

      def has_no_colors_tab?
        header.has_no_tab?("colors")
      end

      def colors_tab
        header.tab("colors")
      end

      def has_settings_tab?
        header.has_tab?("settings")
      end

      def has_no_settings_tab?
        header.has_no_tab?("settings")
      end

      def settings_tab
        header.tab("settings")
      end

      def changes_banner
        PageObjects::Components::AdminChangesBanner.new
      end

      def has_color_scheme_selector?
        page.has_css?(".theme-settings__color-scheme")
      end

      def has_no_color_scheme_selector?
        page.has_no_css?(".theme-settings__color-scheme")
      end

      def color_palette_editor
        PageObjects::Components::ColorPaletteEditor.new(page.find(".color-palette-editor"))
      end

      def palette_editor_save_button
        page.find(".admin-theme__save-palette-changes")
      end

      def has_palette_editor_save_button?
        page.has_css?(".admin-theme__save-palette-changes")
      end

      def has_no_palette_editor_save_button?
        page.has_no_css?(".admin-theme__save-palette-changes")
      end

      def palette_editor_discard_button
        page.find(".admin-theme__discard-palette-changes")
      end

      def has_palette_editor_discard_button?
        page.has_css?(".admin-theme__discard-palette-changes")
      end

      def has_no_palette_editor_discard_button?
        page.has_no_css?(".admin-theme__discard-palette-changes")
      end

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

      def has_no_themes_list?
        has_no_css?(".themes-list-header")
      end

      def has_back_button_to_themes_page?
        has_css?(
          '.back-to-themes-and-components a[href="/admin/config/customize/themes"]',
          text: I18n.t("admin_js.admin.config_areas.themes_and_components.themes.back"),
        )
      end

      def click_back_to_themes
        find(".back-to-themes-and-components a").click
      end

      def has_back_button_to_components_page?
        has_css?(
          '.back-to-themes-and-components a[href="/admin/config/customize/components"]',
          text: I18n.t("admin_js.admin.config_areas.themes_and_components.components.back"),
        )
      end

      def has_no_page_header?
        has_no_css?(".d-page-header")
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
        PageObjects::Components::AdminThemeSettingsEditor.new.opened?
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

      def click_delete
        find(".theme-controls .btn-danger").click
      end

      def confirm_delete
        find(".dialog-footer .btn-danger").click
      end

      def included_components_selector
        PageObjects::Components::SelectKit.new(".included-components-setting .select-kit")
      end

      def relative_themes_save_button
        find(".relative-theme-selector .setting-controls__ok")
      end

      def has_reset_button_for_setting?(css_selector)
        has_css?("#{css_selector} .setting-controls__undo")
      end

      private

      def setting_selector(setting_name, overridden: false)
        "section.theme.settings .setting#{overridden ? ".overridden" : ""}[data-setting=\"#{setting_name}\"]"
      end
    end
  end
end
