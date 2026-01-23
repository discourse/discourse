# frozen_string_literal: true

module Jobs
  class CheckUpcomingChanges < ::Jobs::Scheduled
    every 20.minutes

    def execute(args)
      site = RailsMultisite::ConnectionManagement.current_db

      return if !SiteSetting.enable_upcoming_changes

      verbose_log(
        site,
        :info,
        "Starting change tracker and promotion notifier for upcoming changes",
      )

      if SiteSetting.upcoming_change_site_settings.empty?
        verbose_log(site, :info, "No upcoming changes present.")
        return
      end

      DistributedMutex.synchronize("check_upcoming_changes_#{site}", validity: 10.minutes) do
        track_changes(site)
        notify_promotions(site)
      end
    end

    private

    def track_changes(site)
      UpcomingChanges::Track.call(guardian: Discourse.system_user.guardian) do |result|
        on_success do |added_changes:, removed_changes:, notified_admins_for_added_changes:, status_changes:|
          added_changes.each do |change_name|
            verbose_log(site, :info, "Added upcoming change '#{change_name}'")
          end

          notified_admins_for_added_changes.each do |change_name|
            verbose_log(
              site,
              :info,
              "Notified site admins about added upcoming change '#{change_name}'",
            )
          end

          removed_changes.each do |change_name|
            verbose_log(site, :info, "Removed upcoming change '#{change_name}'")
          end

          status_changes.each do |change_name, details|
            verbose_log(
              site,
              :info,
              "Status changed for upcoming change '#{change_name}' from #{details[:previous_value]} to #{details[:new_value]}",
            )
          end
        end

        on_failure do |error|
          verbose_log(
            site,
            :error,
            "Failed to track upcoming changes, an unexpected error occurred. Error: #{error&.backtrace&.join("\n")}",
          )
        end
      end
    end

    def notify_promotions(site)
      changes_already_notified_about_promotion =
        UpcomingChangeEvent
          .where(
            upcoming_change_name: SiteSetting.upcoming_change_site_settings,
            event_type: :admins_notified_automatic_promotion,
          )
          .pluck(:upcoming_change_name)
          .map(&:to_sym)

      SiteSetting.upcoming_change_site_settings.each do |setting_name|
        unless UpcomingChanges.meets_or_exceeds_status?(
                 setting_name,
                 SiteSetting.promote_upcoming_changes_on_status.to_sym,
               )
          next
        end

        next if changes_already_notified_about_promotion.include?(setting_name)

        UpcomingChanges::NotifyPromotion.call(
          params: {
            setting_name:,
          },
          guardian: Guardian.new(Discourse.system_user),
        ) do |result|
          on_success do
            verbose_log(site, :info, "Notified admins about promotion of '#{setting_name}'")
          end

          on_failure do |error|
            verbose_log(
              site,
              :error,
              "Failed to notify about '#{setting_name}': #{error&.backtrace&.join("\n")}",
            )
          end
        end
      end
    end

    def verbose_log(site, level, message)
      return unless SiteSetting.upcoming_change_verbose_logging
      Rails.logger.public_send(level, "[CheckUpcomingChanges (#{site})] #{message}")
    end
  end
end
