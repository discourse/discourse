# frozen_string_literal: true

# Copies the same schema as SiteSetting, since the values and
# data types are identical. This table is used as a way for themes
# to overrride specific site settings that we make available in
# core based on the `themeable` designation on a site setting.
class ThemeSiteSetting < ActiveRecord::Base
  validate :ensure_setting_themeable

  def ensure_setting_themeable
    return if SiteSetting.themeable[self.name.to_sym]
    errors.add(:base, "#{self.name} is not a themeable site setting")
  end

  # TODO (martin)
  # When creating these, we need to do a similar thing to
  # when site settings are created/updated, like sending a
  # MessageBus update to the UI for client settings, logging,
  # and so on. Probably will need a service...
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
