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

  def self.can_access_db?
    !GlobalSetting.skip_redis? && !GlobalSetting.skip_db? &&
      ActiveRecord::Base.connection.table_exists?(self.table_name)
  end

  # Lightweight override similar to what SiteSettings::DbProvider and
  # SiteSettings::LocalProcessProvider do.
  #
  # This is used to ensure that we don't try to load settings from Redis or
  # the database when they are not available.
  def self.all
    return [] if !can_access_db?
    super
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
