# frozen_string_literal: true
#
# Promotes upcoming changes (defined in site_settings.yml) based
# on their status, and the configured promote_upcoming_changes_on_status
# site setting for the site.

Rails.application.config.after_initialize do
  RailsMultisite::ConnectionManagement.safe_each_connection do
    next if !SiteSetting.enable_upcoming_changes

    begin
      if SiteSetting.upcoming_change_verbose_logging
        Rails.logger.info("[Upcoming changes] Starting promotion check for upcoming changes.")
      end

      SiteSetting.upcoming_change_site_settings.each do |setting_name|
        UpcomingChanges::Promoter.call(
          params: {
            setting: setting_name,
            promotion_status_threshold: SiteSetting.promote_upcoming_changes_on_status,
          },
        ) do |result|
          on_failed_policy(:meets_promotion_criteria) do
            if SiteSetting.upcoming_change_verbose_logging
              Rails.logger.warn(
                "[Upcoming changes] #{setting_name} did not meet promotion criteria. Current status is #{UpcomingChanges.change_status(setting_name)}, required status is #{SiteSetting.promote_upcoming_changes_on_status}.",
              )
            end
          end

          on_failed_policy(:setting_not_modified) do
            if SiteSetting.upcoming_change_verbose_logging
              Rails.logger.warn(
                "[Upcoming changes] #{setting_name} has already been modified by an admin, skipping promotion.",
              )
            end
          end

          on_failed_policy(:setting_not_already_enabled) do
            if SiteSetting.upcoming_change_verbose_logging
              Rails.logger.warn(
                "[Upcoming changes] #{setting_name} is already enabled, skipping promotion.",
              )
            end
          end

          on_failure do |error|
            if SiteSetting.upcoming_change_verbose_logging
              Rails.logger.error(
                "[Upcoming changes] Failed to promote #{setting_name}: #{error.inspect}",
              )
            end
          end

          on_success do
            if SiteSetting.upcoming_change_verbose_logging
              Rails.logger.info(
                "[Upcoming changes] Successfully promoted #{setting_name} to enabled.",
              )
            end
          end
        end
      end
    end
  end
end
