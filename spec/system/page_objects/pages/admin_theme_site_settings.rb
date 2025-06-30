# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminThemeSiteSettings < PageObjects::Pages::AdminBase
      def has_setting_with_default?(setting_name)
        setting_row(setting_name).has_css?(
          ".admin-theme-site-settings-row__setting .setting-label",
          text: SiteSetting.humanized_name(setting_name),
        )
        setting_row(setting_name).has_css?(
          ".admin-theme-site-settings-row__setting .setting-description",
          text: SiteSetting.description(setting_name),
        )
        setting_row(setting_name).has_css?(
          ".admin-theme-site-settings-row__default",
          text: SiteSetting.defaults[setting_name],
        )
      end

      def has_theme_overriding?(setting_name, theme, overrride_value)
        setting_row(setting_name).has_css?(theme_overriding_css(theme), text: theme.name)
        find(theme_overriding_css(theme)).hover
        find(".fk-d-tooltip__content.-content.-expanded").has_content?(
          I18n.t("admin_js.admin.theme_site_settings.overridden_value", value: overrride_value),
        )
      end

      def theme_overriding_css(theme)
        ".admin-theme-site-settings-row__overridden .theme-link[data-theme-id='#{theme.id}']"
      end

      def setting_row(setting_name)
        page.find(
          ".d-admin-row__content.admin-theme-site-settings-row[data-setting-name='#{setting_name}']",
        )
      end
    end
  end
end
