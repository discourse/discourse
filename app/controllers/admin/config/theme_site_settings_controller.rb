# frozen_string_literal: true

class Admin::Config::ThemeSiteSettingsController < Admin::AdminController
  rescue_from Discourse::InvalidParameters do |e|
    render_json_error e.message, status: 422
  end

  def index
    respond_to do |format|
      format.json do
        themeable_site_settings = SiteSetting.themeable.select { |key, value| value }.keys
        themes_with_site_setting_overrides = {}

        # Initialize all themeable settings with empty arrays
        themeable_site_settings.each do |setting_name|
          themes_with_site_setting_overrides[setting_name] = {
            setting_name: setting_name,
            setting_description: SiteSetting.description(setting_name),
            themes: [],
          }
        end

        # Get all themes that have overridden any themeable site setting
        sql = <<~SQL
          SELECT t.id AS theme_id, t.name AS theme_name, tss.name AS setting_name, tss.value, tss.data_type
          FROM themes t
          INNER JOIN theme_site_settings tss ON t.id = tss.theme_id
          WHERE t.component = false AND tss.name IN (:setting_names)
          ORDER BY tss.name, t.name
        SQL

        DB
          .query(sql, setting_names: themeable_site_settings)
          .each do |row|
            setting_name = row.setting_name.to_sym

            themes_with_site_setting_overrides[setting_name][:themes] << {
              theme_id: row.theme_id,
              theme_name: row.theme_name,
              value:
                SiteSetting.type_supervisor.to_rb_value(setting_name, row.value, row.data_type),
            }
          end

        render_json_dump(
          themeable_site_settings: themeable_site_settings,
          themes_with_site_setting_overrides: themes_with_site_setting_overrides,
        )
      end
    end
  end
end
