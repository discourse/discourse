# frozen_string_literal: true

# Responsible for resolving all possible theme site settings for
# a given theme, including details about the setting type, valid values,
# and description, for use in the theme editor.
#
# The value of the setting will either be the value stored in the
# ThemeSiteSetting table, or the default value of the site setting.
#
# Example output for a single setting, there will be an array of these:
#
# {
#   :setting=>:search_experience,
#   :default=>"search_icon",
#   :description=>"The default position and appearance of search on desktop devices",
#   :type=>"enum",
#   :valid_values=>[
#     {
#       :name=>"search.experience.search_field", :value=>"search_field"
#     }, {
#       :name=>"search.experience.search_icon", :value=>"search_icon"
#     }
#   ],
#   :translate_names=>true,
#   :value=>"search_icon"
# }
class ThemeSiteSettingResolver
  attr_reader :theme

  def initialize(theme:)
    @theme = theme
  end

  def resolved_theme_site_settings
    stored_theme_site_settings =
      theme.theme_site_settings.where(name: SiteSetting.themeable_site_settings).to_a

    SiteSetting
      .themeable_site_settings
      .each_with_object([]) do |setting, settings|
        setting_hash = SiteSetting.setting_metadata_hash(setting)

        # If the setting has been saved in the DB, it means the theme has changed
        # it in about.json on import, or the admin has changed it manually later on.
        stored_setting =
          stored_theme_site_settings.find { |db_setting| db_setting.name == setting.to_s }
        if !stored_setting.nil?
          setting_hash[:value] = stored_setting.setting_rb_value
        else
          # Otherwise if there is no value in the DB, we use the default value of
          # the site setting, since we do not insert a DB value if the about.json
          # value is the same as the default site setting value.
          setting_hash[:value] = setting_hash[:default]
        end

        settings << setting_hash
      end
      .sort_by { |setting_hash| setting_hash[:setting] }
  end
end
