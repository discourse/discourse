# frozen_string_literal: true
#
# Tracks both the addition and removal of upcoming changes by
# observing site_settings/settings.yml files and writing to
# an upcoming change event log.
#
# Added upcoming changes will send a notification to site admins
# to inform them that the change is now available to opt-in,
# as long as the status of the change is one less than
# SiteSetting.promote_upcoming_changes_on_status. For example,
# if a site has `beta` for the promotion status, we only notify
# admins when the change reaches `alpha`.
#
# We may end up with separate added & status change events, and
# the admin  should only be notified when the status is actually
# SiteSetting.promote_upcoming_changes_on_status - 1 OR gte
# SiteSetting.promote_upcoming_changes_on_status.
#
# Removed upcoming changes will be logged. After some time,
# if the setting related to the change no longer exists, the
# setting value in the site_settings table will be deleted
# in a cleanup job.

require "upcoming_changes"
require "upcoming_changes/tracking_initializer"

Rails.application.config.after_initialize { UpcomingChanges::TrackingInitializer.call }
