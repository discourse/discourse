# frozen_string_literal: true

class Admin::Config::ThemeSiteSettingsController < Admin::AdminController
  def index
    respond_to do |format|
      format.json do
        themes_with_site_setting_overrides = {}

        SiteSetting.themeable_site_settings.each do |setting_name|
          themes_with_site_setting_overrides[setting_name] = SiteSetting.setting_metadata_hash(
            setting_name,
          ).merge(themes: [])
        end

        ThemeSiteSetting.themes_with_overridden_settings.each do |row|
          themes_with_site_setting_overrides[row.setting_name][:themes] << {
            theme_id: row.theme_id,
            theme_name: row.theme_name,
            value: row.value,
          }
        end

        render_json_dump(
          themeable_site_settings: SiteSetting.themeable_site_settings,
          themes_with_site_setting_overrides: themes_with_site_setting_overrides,
        )
      end
    end
  end
end
