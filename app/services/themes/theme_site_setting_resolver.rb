# frozen_string_literal: true

class Themes::ThemeSiteSettingResolver
  include Service::Base

  params do
    attribute :theme_id, :integer
    validates :theme_id, presence: true
  end

  model :themeable_site_setting_names
  model :theme
  model :stored_theme_site_settings, optional: true
  model :resolved_theme_site_settings

  private

  def fetch_themeable_site_setting_names
    SiteSetting.themeable.select { |_, value| value }.keys
  end

  def fetch_theme(params:)
    Theme.find_by(id: params.theme_id)
  end

  def fetch_stored_theme_site_settings(themeable_site_setting_names:, theme:)
    theme.theme_site_settings.where(name: themeable_site_setting_names)
  end

  def fetch_resolved_theme_site_settings(themeable_site_setting_names:, stored_theme_site_settings:)
    themeable_site_setting_names
      .each_with_object([]) do |setting, settings|
        type_hash = SiteSetting.type_supervisor.type_hash(setting)
        setting_hash = {
          setting: setting,
          type: type_hash[:type],
          # I think this makes more sense...if you are resetting it to the
          # default it means you want it the same as whatever the default
          # site setting is.
          default: SiteSetting.defaults[setting].to_s,
          description: SiteSetting.description(setting),
          valid_values: type_hash[:valid_values],
          translate_names: type_hash[:translate_names],
        }

        # If the setting has been saved in the DB, it means the theme has changed
        # it in about.json on import, or the admin has changed it manually later on.
        db_value = stored_theme_site_settings.find { |db_setting| db_setting.name == setting.to_s }
        if !db_value.nil?
          setting_hash[:value] = SiteSetting
            .type_supervisor
            .to_rb_value(setting, db_value.value, db_value.data_type)
            .to_s
        else
          # Otherwise if there is no value in the DB, we use the default value of
          # the site setting, since we do not insert a DB value if the about.json
          # value is the same as the default site setting value.
          setting_hash[:value] = SiteSetting.defaults[setting].to_s
        end

        settings << setting_hash
      end
      .sort_by { |s| s[:setting] }
  end
end
