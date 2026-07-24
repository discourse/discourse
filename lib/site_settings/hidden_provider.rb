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
    hidden = @hidden_settings

    # Settings hidden because an upcoming change that replaces them is enabled.
    # Unioned before the modifier so plugins can still explicitly un-hide a
    # setting via the :hidden_site_settings modifier. Skipped entirely when no
    # change opts in, to avoid allocating a new Set on every read.
    upcoming_change_hidden = UpcomingChanges.settings_hidden_while_enabled
    hidden = hidden | upcoming_change_hidden if upcoming_change_hidden.present?

    DiscoursePluginRegistry.apply_modifier(:hidden_site_settings, hidden)
  end
end
