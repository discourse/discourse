# frozen_string_literal: true

# Copies the same schema as SiteSetting, since the values and
# data types are identical. This table is used as a way for themes
# to overrride specific site settings that we make available in
# core based on the `themeable` designation on a site setting.
#
# Creation, updating, and deletion of theme site settings is done
# via the `Themes::ThemeSiteSettingManager` service.
class ThemeSiteSetting < ActiveRecord::Base
  belongs_to :theme

  def self.themes_with_overridden_settings
    sql = <<~SQL
      SELECT theme.id AS theme_id, theme.name AS theme_name,
        tss.name AS setting_name, tss.value, tss.data_type
      FROM themes theme
      INNER JOIN theme_site_settings tss ON theme.id = tss.theme_id
      WHERE theme.component = false AND tss.name IN (:setting_names)
      ORDER BY tss.name, theme.name
    SQL

    DB
      .query(sql, setting_names: SiteSetting.themeable_site_settings)
      .each do |row|
        row.setting_name = row.setting_name.to_sym
        row.value =
          SiteSetting.type_supervisor.to_rb_value(row.setting_name, row.value, row.data_type)
      end
  end

  def self.can_access_db?
    !GlobalSetting.skip_redis? && !GlobalSetting.skip_db? &&
      ActiveRecord::Base.connection.table_exists?(self.table_name)
  end

  # Lightweight override similar to what SiteSettings::DbProvider and
  # SiteSettings::LocalProcessProvider do.
  #
  # This is used to ensure that we don't try to load settings from Redis or
  # the database when they are not available.
  def self.generate_theme_map
    return {} if !can_access_db?

    theme_site_setting_values_map = {}
    Theme
      .includes(:theme_site_settings)
      .not_components
      .each do |theme|
        SiteSetting.themeable_site_settings.each do |setting_name|
          setting = theme.theme_site_settings.find { |s| s.name == setting_name.to_s }

          value =
            if setting.nil?
              SiteSetting.defaults[setting_name]
            else
              SiteSetting.type_supervisor.to_rb_value(
                setting.name.to_sym,
                setting.value,
                setting.data_type,
              )
            end

          theme_site_setting_values_map[theme.id] ||= {}
          theme_site_setting_values_map[theme.id][setting_name] = value
        end
      end

    theme_site_setting_values_map
  end

  def setting_rb_value
    SiteSetting.type_supervisor.to_rb_value(self.name, self.value, self.data_type).to_s
  end
end

# == Schema Information
#
# Table name: theme_site_settings
#
#  id         :bigint           not null, primary key
#  theme_id   :integer          not null
#  name       :string           not null
#  data_type  :integer          not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_theme_site_settings_on_theme_id           (theme_id)
#  index_theme_site_settings_on_theme_id_and_name  (theme_id,name) UNIQUE
#
