# frozen_string_literal: true

Rails.application.config.after_initialize { UpcomingChanges.clear_caches! }

# While the `remove_and_replace_uncategorized` change is in effect (manual opt-in
# or auto-promotion), the legacy uncategorized settings no longer make sense, so
# hide them. This modifier is re-evaluated on every `hidden_settings` read, so it
# tracks both opt-in paths live and is multisite-safe.
DiscoursePluginRegistry.register_modifier(Plugin::Instance.new, :hidden_site_settings) do |hidden|
  SiteSetting::Action::RemoveAndReplaceUncategorizedToggled.apply_hidden_settings(hidden)
end

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
  if setting_name == :simple_email_subject
    SiteSetting::Action::SimpleEmailSubjectToggled.call(params: { setting_enabled: true })
  elsif setting_name == :enable_horizon_high_context_topic_cards
    Themes::Action::HorizonHighContextTopicCardsToggled.call(enabled: true)
  elsif setting_name == :remove_and_replace_uncategorized
    SiteSetting::Action::RemoveAndReplaceUncategorizedToggled.call(enabled: true)
  end
end

DiscourseEvent.on(:upcoming_change_disabled) do |setting_name|
  # Respond to event here, e.g. if setting_name == :enable_form_templates do X.
  if setting_name == :simple_email_subject
    SiteSetting::Action::SimpleEmailSubjectToggled.call(params: { setting_enabled: false })
  elsif setting_name == :enable_horizon_high_context_topic_cards
    Themes::Action::HorizonHighContextTopicCardsToggled.call(enabled: false)
  elsif setting_name == :remove_and_replace_uncategorized
    SiteSetting::Action::RemoveAndReplaceUncategorizedToggled.call(enabled: false)
  end
end
