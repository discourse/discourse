# frozen_string_literal: true

module SiteSettings
end

# A class to store and modify hidden site settings
class SiteSettings::HiddenProvider
  def initialize
    @hidden_settings = Set.new
  end

  def add_hidden(site_setting_name)
    @hidden_settings << site_setting_name
  end

  def remove_hidden(site_setting_name)
    @hidden_settings.delete(site_setting_name)
  end

  def all
    DiscoursePluginRegistry.apply_modifier(:hidden_site_settings, @hidden_settings)
  end
end
