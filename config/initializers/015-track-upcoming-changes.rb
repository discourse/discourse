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

require_relative "../../lib/upcoming_changes"

Rails.application.config.after_initialize { UpcomingChanges::TrackingInitializer.call }

class UpcomingChanges::TrackingInitializer
  def self.log_prefix(site)
    "[Upcoming changes tracker (#{site})]:"
  end

  def self.verbose_log(site, level, message)
    return unless SiteSetting.upcoming_change_verbose_logging
    Rails.logger.public_send(level, "#{log_prefix(site)} #{message}")
  end

  def self.call
    RailsMultisite::ConnectionManagement.safe_each_connection do |site|
      next if !SiteSetting.enable_upcoming_changes

      verbose_log(site, :info, "Beginning tracking initializer for upcoming changes")

      if SiteSetting.upcoming_change_site_settings.empty?
        verbose_log(site, :info, "No upcoming changes present.")
        next
      end

      UpcomingChangeEvent.added_changes.pluck(:upcoming_change_name)

      # Look at UpcomingChangeEvent to get all event_type: added (0) events
      #   -> Compare with SiteSetting.upcoming_change_site_settings to see if there are any missing
      #       -> if so, create an event for the added changes
      #       -> send notifications to all site admins IF the event is the correct status (promotion_status - 1)
      #
      # Lookup any event_type: added (events) and compare with removed (1) events and see if there are any
      # added that are no longer in SiteSetting.upcoming_change_site_settings with no corresponding removed (1) event
      #   -> Create an event for the removed changes
      #
      # Lookup any previous event_type: status_changed (5) events for the change
      #   -> If there are none, create one for the current status
      #     -> Add previous_value and new_value in event_data
      #   -> Send an appropriate notification to admins
      #     -> If the change was also added at the same time, and the status is correct (promotion_status - 1),
      #     then don't send another notification
      #     -> If the change was not added, send a notification about the status change if  it's the correct
      #     status (promotion_status - 1) to indicate it's available to admins
      #
      # ---
      #
      # For "Upcoming changes *" in sidebar:
      #   * Add `last_visited_upcoming_changes`  datetime in the user table
      #   * Only serialize for admins and moderators
      #   * If there is an added (0) event created > `last_visited_upcoming_changes` then  show the dot
      #   * Update `last_visited_upcoming_changes` when  going to /admin/config/upcoming-changes
      #   * (?) Maybe add a way to filter only "new" items on the upcoming change page? Or at least see
      #   the log entries?
    end
  end
end
