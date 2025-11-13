# frozen_string_literal: true
class Admin::Config::WelcomeBannerController < Admin::AdminController
  def index
  end

  def themes_with_setting
    themes =
      Theme
        .not_components
        .where("themes.id = ? OR themes.user_selectable = ?", SiteSetting.default_theme_id, true)
        .includes(:theme_site_settings)

    themes_data =
      themes.map do |theme|
        setting = theme.theme_site_settings.find { |s| s.name == "enable_welcome_banner" }
        value =
          if setting
            # Boolean values are stored as "t" or "f" in the database
            setting.value == "t" || setting.value == "true" || setting.value == true
          else
            false
          end

        { id: theme.id, name: theme.name, enable_welcome_banner: value }
      end

    render json: { themes: themes_data }
  end
end
