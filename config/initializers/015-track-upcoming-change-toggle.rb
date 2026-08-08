# frozen_string_literal: true

Rails.application.config.after_initialize { UpcomingChanges.clear_caches! }

#
# Similar to 014-track-setting-changes.rb, we can react to upcoming changes
# being enabled/or disabled here for more complicated scenarios, where
# we are not just changing UI or behaviour when the state of the underlying
# setting is changed.
#
# We need to do this separately from 014-track-setting-changes.rb because
# we don't actually change the underlying setting value in the database
# when an upcoming change is automatically promoted. See UpcomingChanges::NotifyPromotions
# for further context.
#
# We do also send these events when admins manually opt-in or opt-out of an upcoming change
# via the UI and the UpcomingChanges::Toggle service.

DiscourseEvent.on(:upcoming_change_enabled) do |setting_name|
  # Respond to event here, e.g. if setting_name == :enable_form_templates do X.
  if setting_name == :enable_horizon_high_context_topic_cards
    Themes::Action::HorizonHighContextTopicCardsToggled.call(enabled: true)
  elsif setting_name == :remove_and_replace_uncategorized
    SiteSetting::Action::RemoveAndReplaceUncategorizedToggled.call(enabled: true)
  end
end

DiscourseEvent.on(:upcoming_change_disabled) do |setting_name|
  # Respond to event here, e.g. if setting_name == :enable_form_templates do X.
  if setting_name == :enable_horizon_high_context_topic_cards
    Themes::Action::HorizonHighContextTopicCardsToggled.call(enabled: false)
  elsif setting_name == :remove_and_replace_uncategorized
    SiteSetting::Action::RemoveAndReplaceUncategorizedToggled.call(enabled: false)
  end
end

# A plugin's settings are registered whether or not it is enabled, so its upcoming
# changes have been accumulating in the audit trail all along, only
# ConditionalDisplay was holding their notifications back. Enabling the plugin would
# otherwise release that whole back-catalogue at once, which is noise. The admin just
# opted into the plugin, they did not have anything change out from under them, so they
# don't need to have a flood of notifications.
#
# Treat it the same way as a new site and mark those changes as already notified
# about. Promotion itself still happens, so :upcoming_change_enabled fires as usual.
DiscourseEvent.on(:site_setting_changed) do |name, _old_value, new_value|
  next if !new_value

  plugin_name = SiteSetting.plugins[name]
  next if plugin_name.blank?

  plugin = Discourse.plugins_by_name[plugin_name]
  next if plugin&.enabled_site_setting&.to_sym != name.to_sym

  all_plugin_upcoming_changes =
    SiteSetting.upcoming_change_site_settings.select do |change_name|
      SiteSetting.plugins[change_name] == plugin_name
    end
  next if all_plugin_upcoming_changes.blank?

  UpcomingChanges::Action::BackfillNotifiedEvents.call(
    upcoming_change_names: all_plugin_upcoming_changes,
  )
end
