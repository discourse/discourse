# frozen_string_literal: true

module UpcomingChanges
  class TrackingInitializer
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

        DistributedMutex.synchronize("track_upcoming_changes_#{site}") do
          UpcomingChanges::Track.call(guardian: Guardian.new(Discourse.system_user)) do |result|
            on_success do |added_changes:, removed_changes:, notified_admins_for_added_changes:, status_changes:|
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
        end
      end
    end
  end
end
