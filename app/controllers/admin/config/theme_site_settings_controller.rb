# frozen_string_literal: true

class Admin::Config::ThemeSiteSettingsController < Admin::AdminController
  rescue_from Discourse::InvalidParameters do |e|
    render_json_error e.message, status: 422
  end

  def index
    params.permit(:theme_id)

    respond_to do |format|
      format.json do
        setting_name = params[:setting_name]
        theme_site_settings = nil

        if setting_name.present?
          default_value = SiteSetting.defaults[setting_name.to_sym]

          # This query joins themes with theme_site_settings using a LEFT OUTER JOIN
          # so we get all themes even if they don't have the specific setting
          sql = <<~SQL
                  SELECT t.id AS theme_id, t.name AS theme_name, tss.value, tss.data_type
                  FROM themes t
                  LEFT OUTER JOIN theme_site_settings tss
                    ON t.id = tss.theme_id AND tss.name = :setting_name
                  WHERE t.component = false
                  ORDER BY t.name
                SQL

          theme_site_settings =
            DB
              .query(sql, setting_name: setting_name)
              .map do |row|
                {
                  theme_id: row.theme_id,
                  theme_name: row.theme_name,
                  value:
                    (
                      if row.value.nil?
                        default_value
                      else
                        SiteSetting.type_supervisor.to_rb_value(
                          setting_name,
                          row.value,
                          row.data_type,
                        )
                      end
                    ),
                  is_default: row.value.nil?,
                  setting: setting_name,
                }
              end
              .as_json
        end

        render_json_dump(
          theme_site_settings: theme_site_settings,
          themeable_site_settings: SiteSetting.themeable.select { |key, value| value }.keys,
        )
      end
    end
  end
end
