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
    "[Upcoming changes tracker (#{site})]: "
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

      UpcomingChanges::Track.call(guardian: Guardian.new(Discourse.system_user)) do |result|
        on_success do |added_changes:, removed_changes:, notified_admins_for_added_changes:|
          added_changes.each do |change_name|
            verbose_log(site, :info, "added upcoming change '#{change_name}'")
          end

          notified_admins_for_added_changes.each do |change_name|
            verbose_log(
              site,
              :info,
              "notified site admins about added upcoming change '#{change_name}'",
            )
          end

          removed_changes.each do |change_name|
            verbose_log(site, :info, "removed upcoming change '#{change_name}'")
          end

          status_changes.each do |change_name, details|
            verbose_log(
              site,
              :info,
              "status changed for upcoming change '#{change_name}' from #{details[:previous_value]} to #{details[:new_value]}",
            )
          end
        end

        on_failure do |error|
          verbose_log(
            site,
            :error,
            "Failed to track upcoming changes', an unexpected error occurred. Error: #{error&.backtrace&.join("\n")}",
          )
        end
      end

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
