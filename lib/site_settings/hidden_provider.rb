# frozen_string_literal: true

module SiteSettings
end

# A cache for providing default value based on site locale
class SiteSettings::HiddenProvider
  def initialize
    @hidden_settings = []
  end

  def add_hidden(site_setting_name)
    @hidden_settings << site_setting_name unless @hidden_settings.include?(site_setting_name)
  end

  def all
    DiscoursePluginRegistry.apply_modifier(:hidden_site_settings, @hidden_settings)
  end
end
