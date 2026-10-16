# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomizeThemes < PageObjects::Pages::AdminBase
      def visit(theme_or_theme_id)
        browser_page
          .goto(
            "/admin/customize/themes/#{theme_or_theme_id.is_a?(Theme) ? theme_or_theme_id.id : theme_or_theme_id}",
          )
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def finish_install
        browser_root.locator(".finish-install").filter(visible: true).click
      end

      def has_incomplete_installation?
        have_count(0).does_not_match?(
          browser_root
            .get_by_role("button")
            .and(
              browser_root.locator(
                "[id=#{I18n.t("admin_js.admin.customize.theme.finish_install").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.finish_install").to_s.to_json}]",
              ).or(
                browser_root.get_by_role(
                  "button",
                  name: I18n.t("admin_js.admin.customize.theme.finish_install"),
                ),
              ),
            )
            .filter(visible: true),
        )
      end

      def visit_editor(theme, target: "common", field: "scss")
        browser_page
          .goto("/admin/customize/themes/#{theme.id}/#{target}/#{field}/edit")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def click_editor_field(field)
        browser_root
          .locator(".nav-pills.fields a[href$='/#{field}/edit']")
          .filter(visible: true)
          .click
      end

      def has_editor_field_description?(field)
        contain_text(
          [browser_text_pattern(I18n.t("admin_js.admin.customize.theme.#{field}.title"))],
          useInnerText: true,
        ).matches?(browser_root.locator(".field-info").filter(visible: true))
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
        have_count(0).does_not_match?(
          browser_root.locator(".theme-settings__color-scheme").filter(visible: true),
        )
      end

      def has_no_color_scheme_selector?
        have_count(0).matches?(
          browser_root.locator(".theme-settings__color-scheme").filter(visible: true),
        )
      end

      def color_palette_editor
        PageObjects::Components::ColorPaletteEditor.new(
          browser_root.locator(".color-palette-editor").filter(visible: true),
        )
      end

      def palette_editor_save_button
        browser_root.locator(".admin-theme__save-palette-changes").filter(visible: true)
      end

      def has_palette_editor_save_button?
        have_count(0).does_not_match?(
          browser_root.locator(".admin-theme__save-palette-changes").filter(visible: true),
        )
      end

      def has_no_palette_editor_save_button?
        have_count(0).matches?(
          browser_root.locator(".admin-theme__save-palette-changes").filter(visible: true),
        )
      end

      def palette_editor_discard_button
        browser_root.locator(".admin-theme__discard-palette-changes").filter(visible: true)
      end

      def has_palette_editor_discard_button?
        have_count(0).does_not_match?(
          browser_root.locator(".admin-theme__discard-palette-changes").filter(visible: true),
        )
      end

      def has_no_palette_editor_discard_button?
        have_count(0).matches?(
          browser_root.locator(".admin-theme__discard-palette-changes").filter(visible: true),
        )
      end

      def has_inactive_themes?
        have_count(0).does_not_match?(
          browser_root.locator(".inactive-indicator").filter(visible: true),
        )
      end

      def has_no_inactive_themes?
        have_count(0).matches?(browser_root.locator(".inactive-indicator").filter(visible: true))
      end

      def has_select_inactive_mode_button?
        have_count(0).does_not_match?(
          browser_root.locator(".select-inactive-mode").filter(visible: true),
        )
      end

      def has_overridden_setting?(setting_name)
        have_count(0).does_not_match?(
          browser_root.locator(setting_selector(setting_name, overridden: true)).filter(
            visible: true,
          ),
        )
      end

      def has_no_overriden_setting?(setting_name)
        have_count(0).matches?(
          browser_root.locator(setting_selector(setting_name, overridden: true)).filter(
            visible: true,
          ),
        )
      end

      def has_setting_description?(setting_name, description)
        contain_text([browser_exact_text_pattern(description)], useInnerText: true).matches?(
          browser_root.locator("#{setting_selector(setting_name)} .desc").filter(visible: true),
        )
      end

      def has_theme_site_setting?(setting_name)
        expect(
          browser_root
            .locator(theme_site_setting_selector(setting_name))
            .filter(visible: true)
            .locator(".setting-label")
            .filter(visible: true),
        ).to contain_text(
          [browser_text_pattern(SiteSetting.humanized_name(setting_name))],
          useInnerText: true,
        )
        contain_text(
          [browser_text_pattern(SiteSetting.description(setting_name))],
          useInnerText: true,
        ).matches?(
          browser_root
            .locator(theme_site_setting_selector(setting_name))
            .filter(visible: true)
            .locator(".setting-value")
            .filter(visible: true),
        )
      end

      def has_overridden_theme_site_setting?(setting_name)
        have_count(0).does_not_match?(
          browser_root.locator(theme_site_setting_selector(setting_name, overridden: true)).filter(
            visible: true,
          ),
        )
      end

      def has_no_overridden_theme_site_setting?(setting_name)
        have_count(0).matches?(
          browser_root.locator(theme_site_setting_selector(setting_name, overridden: true)).filter(
            visible: true,
          ),
        )
      end

      def toggle_theme_site_setting(setting_name)
        browser_root
          .locator(theme_site_setting_selector(setting_name))
          .filter(visible: true)
          .locator(".setting-value input[type='checkbox']")
          .filter(visible: true)
          .click
        browser_root
          .locator(theme_site_setting_selector(setting_name))
          .filter(visible: true)
          .locator(".setting-controls .ok")
          .filter(visible: true)
          .click
      end

      def reset_overridden_theme_site_setting(setting_name)
        browser_root
          .locator(theme_site_setting_selector(setting_name, overridden: true))
          .filter(visible: true)
          .locator(".setting-controls__undo")
          .filter(visible: true)
          .click
        browser_root
          .locator(theme_site_setting_selector(setting_name))
          .filter(visible: true)
          .locator(".setting-controls .ok")
          .filter(visible: true)
          .click
      end

      def has_no_themes_list?
        have_count(0).matches?(browser_root.locator(".themes-list-header").filter(visible: true))
      end

      def has_back_button_to_themes_page?
        contain_text(
          [
            browser_text_pattern(
              I18n.t("admin_js.admin.config_areas.themes_and_components.themes.back"),
            ),
          ],
          useInnerText: true,
        ).matches?(
          browser_root.locator(
            '.back-to-themes-and-components a[href="/admin/config/customize/themes"]',
          ).filter(visible: true),
        )
      end

      def click_back_to_themes
        browser_root.locator(".back-to-themes-and-components a").filter(visible: true).click
      end

      def has_back_button_to_components_page?
        contain_text(
          [
            browser_text_pattern(
              I18n.t("admin_js.admin.config_areas.themes_and_components.components.back"),
            ),
          ],
          useInnerText: true,
        ).matches?(
          browser_root.locator(
            '.back-to-themes-and-components a[href="/admin/config/customize/components"]',
          ).filter(visible: true),
        )
      end

      def click_back_to_components
        browser_root
          .locator('.back-to-themes-and-components a[href="/admin/config/customize/components"]')
          .filter(visible: true)
          .click
      end

      def fill_in_setting(setting_name, value)
        browser_root
          .locator("#{setting_selector(setting_name)} input.input-setting-string")
          .filter(visible: true)
          .fill(value)
        self
      end

      def has_setting_value?(setting_name, value)
        have_value(value).matches?(
          browser_root.locator(
            "#{setting_selector(setting_name)} input.input-setting-string",
          ).filter(visible: true),
        )
      end

      def click_edit_code
        browser_root.locator(".edit-code").filter(visible: true).click
      end

      def click_add_all_themes_button
        browser_root
          .locator(".relative-theme-selector .setting-label .btn-link")
          .filter(visible: true)
          .click
        browser_root.locator(".setting-controls .ok").filter(visible: true).click
      end

      def has_no_page_header?
        have_count(0).matches?(browser_root.locator(".d-page-header").filter(visible: true))
      end

      def reset_overridden_setting(setting_name)
        setting_section =
          browser_root.locator(
            "section.theme.settings .setting[data-setting=\"#{setting_name}\"]",
          ).filter(visible: true)
        setting_section
          .locator(
            "[id=#{I18n.t("admin_js.admin.settings.reset").to_s.to_json}], [name=#{I18n.t("admin_js.admin.settings.reset").to_s.to_json}]",
          )
          .or(setting_section.get_by_role("button", name: I18n.t("admin_js.admin.settings.reset")))
          .filter(visible: true)
          .click
        setting_section.locator(".setting-controls .ok").filter(visible: true).click
      end

      def click_select_inactive_mode
        browser_root.locator(".select-inactive-mode").filter(visible: true).click
      end

      def cancel_select_inactive_mode
        browser_root.locator(".cancel-select-inactive-mode").filter(visible: true).click
      end

      def has_inactive_themes_selected?(count:)
        have_count(count).matches?(
          browser_root.locator(".inactive-theme input:checked").filter(visible: true),
        )
      end

      def has_themes?(count:)
        have_count(count).matches?(
          browser_root.locator(".themes-list-container__item").filter(visible: true),
        )
      end

      def toggle_all_inactive
        browser_root.locator(".toggle-all-inactive").filter(visible: true).click
      end

      def has_disabled_delete_theme_button?
        browser_root
          .get_by_role("button")
          .and(
            browser_root.locator(
              "[id=#{"Delete".to_s.to_json}], [name=#{"Delete".to_s.to_json}]",
            ).or(browser_root.get_by_role("button", name: "Delete")),
          )
          .and(browser_root.locator(":disabled"))
          .filter(visible: true)
      end

      def click_delete_button_and_confirm
        browser_root.locator(".delete").filter(visible: true).click
        PageObjects::Components::Dialog.new.click_danger
        self
      end

      def click_edit_objects_setting_button(setting_name)
        browser_root
          .locator(".theme-setting[data-setting=\"#{setting_name}\"] .setting-value-edit-button")
          .filter(visible: true)
          .click
        PageObjects::Pages::AdminObjectsSettingEditor.new
      end

      def click_theme_settings_editor_button
        browser_root
          .locator(
            "[id=#{I18n.t("admin_js.admin.customize.theme.settings_editor").to_s.to_json}], [name=#{I18n.t("admin_js.admin.customize.theme.settings_editor").to_s.to_json}]",
          )
          .or(
            browser_root.get_by_role(
              "button",
              name: I18n.t("admin_js.admin.customize.theme.settings_editor"),
            ),
          )
          .filter(visible: true)
          .click
        PageObjects::Components::AdminThemeSettingsEditor.new.opened?
      end

      def switch_to_components
        browser_root.locator(".components-tab").filter(visible: true).click
      end

      def switch_to_themes
        browser_root.locator(".themes-tab").filter(visible: true).click
      end

      def search(term)
        browser_root.locator(".themes-list-search__input").filter(visible: true).fill(term)
      end

      def has_no_search?
        have_count(0).matches?(
          browser_root.locator(".themes-list-search__input").filter(visible: true),
        )
      end

      def click_delete
        browser_root.locator(".theme-controls .btn-danger").filter(visible: true).click
      end

      def confirm_delete
        browser_root.locator(".dialog-footer .btn-danger").filter(visible: true).click
      end

      def parent_themes_selector
        PageObjects::Components::SelectKit.new(".parent-themes-setting .select-kit")
      end

      def included_components_selector
        PageObjects::Components::SelectKit.new(".included-components-setting .select-kit")
      end

      def relative_themes_save_button
        browser_root.locator(".relative-theme-selector .setting-controls__ok").filter(visible: true)
      end

      def has_reset_button_for_setting?(css_selector)
        have_count(0).does_not_match?(
          browser_root.locator("#{css_selector} .setting-controls__undo").filter(visible: true),
        )
      end

      private

      def setting_selector(setting_name, overridden: false)
        "section.theme.settings .setting#{overridden ? ".overridden" : ""}[data-setting=\"#{setting_name}\"]"
      end

      def theme_site_setting_selector(setting_name, overridden: false)
        "section.theme.theme-site-settings .setting#{overridden ? ".overridden" : ""}.theme-site-setting[data-setting=\"#{setting_name}\"]"
      end
    end
  end
end
