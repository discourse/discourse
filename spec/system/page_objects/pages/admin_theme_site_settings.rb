# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminThemeSiteSettings < PageObjects::Pages::AdminBase
      def has_setting_with_default?(setting_name)
        expect(
          setting_row(setting_name).locator(
            ".admin-theme-site-settings-row__setting .setting-label",
          ).filter(visible: true),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern(SiteSetting.humanized_name(setting_name))],
          useInnerText: true,
        )
        expect(
          setting_row(setting_name).locator(
            ".admin-theme-site-settings-row__setting .setting-description",
          ).filter(visible: true),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern(SiteSetting.description(setting_name))],
          useInnerText: true,
        )
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(SiteSetting.defaults[setting_name])],
          useInnerText: true,
        ).matches?(
          setting_row(setting_name).locator(".admin-theme-site-settings-row__default").filter(
            visible: true,
          ),
        )
      end

      def has_theme_overriding?(setting_name, theme, overrride_value)
        expect(
          setting_row(setting_name).locator(theme_overriding_css(theme)).filter(visible: true),
        ).to PlaywrightMatchers.contain_text([browser_text_pattern(theme.name)], useInnerText: true)
        browser_root.locator(theme_overriding_css(theme)).filter(visible: true).hover
        PlaywrightMatchers.contain_text(
          browser_text_pattern(
            I18n.t("admin_js.admin.theme_site_settings.overridden_value", value: overrride_value),
          ),
          useInnerText: true,
        ).matches?(
          browser_root.locator(".fk-d-tooltip__content.-content.-expanded").filter(visible: true),
        )
      end

      def theme_overriding_css(theme)
        ".admin-theme-site-settings-row__overridden .theme-link[data-theme-id='#{theme.id}']"
      end

      def setting_row(setting_name)
        browser_root.locator(
          ".d-table__row.admin-theme-site-settings-row[data-setting-name='#{setting_name}']",
        ).filter(visible: true)
      end
    end
  end
end
