# frozen_string_literal: true
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
end

DiscourseEvent.on(:upcoming_change_disabled) do |setting_name|
  # Respond to event here, e.g. if setting_name == :enable_form_templates do X.
end
