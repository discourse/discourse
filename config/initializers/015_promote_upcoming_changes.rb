# frozen_string_literal: true
#
# Promotes upcoming changes (defined in site_settings.yml) based
# on their status, and the configured promote_upcoming_changes_on_status
# site setting for the site.

require_relative "../../lib/upcoming_changes"

Rails.application.config.after_initialize { UpcomingChanges::AutoPromotionInitializer.call }

class UpcomingChanges::AutoPromotionInitializer
  def self.log_prefix(site)
    "[Upcoming changes promoter (#{site})]:"
  end

  def self.call
    RailsMultisite::ConnectionManagement.safe_each_connection do |site|
      next if !SiteSetting.enable_upcoming_changes

      if SiteSetting.upcoming_change_verbose_logging
        Rails.logger.info("#{log_prefix(site)} Starting promotion check for upcoming changes.")
      end

      if SiteSetting.upcoming_change_site_settings.empty?
        if SiteSetting.upcoming_change_verbose_logging
          Rails.logger.info("#{log_prefix(site)} No upcoming changes present.")
        end
        next
      end

      SiteSetting.upcoming_change_site_settings.each do |setting_name|
        UpcomingChanges::Promoter.call(
          params: {
            setting: setting_name,
            promotion_status_threshold: SiteSetting.promote_upcoming_changes_on_status,
          },
          guardian: Guardian.new(Discourse.system_user),
        ) do |result|
          on_failed_policy(:meets_promotion_criteria) do
            if SiteSetting.upcoming_change_verbose_logging
              Rails.logger.warn(
                "#{log_prefix(site)} '#{setting_name}' did not meet promotion criteria. Current status is #{UpcomingChanges.change_status(setting_name)}, required status is #{SiteSetting.promote_upcoming_changes_on_status}.",
              )
            end
          end

          on_failed_policy(:setting_not_modified) do
            if SiteSetting.upcoming_change_verbose_logging
              Rails.logger.warn(
                "#{log_prefix(site)} '#{setting_name}' has already been modified by an admin, skipping promotion.",
              )
            end
          end

          on_failed_policy(:setting_not_already_enabled) do
            if SiteSetting.upcoming_change_verbose_logging
              Rails.logger.warn(
                "#{log_prefix(site)} '#{setting_name}' is already enabled, skipping promotion.",
              )
            end
          end

          on_failed_contract do |contract|
            if SiteSetting.upcoming_change_verbose_logging
              Rails.logger.error(
                "#{log_prefix(site)} Contract failure when promoting '#{setting_name}': #{
                  contract.errors.full_messages.join(", ")
                }",
              )
            end
          end

          on_failure do |error|
            if SiteSetting.upcoming_change_verbose_logging
              Rails.logger.error(
                "#{log_prefix(site)} Failed to promote '#{setting_name}': #{error.inspect}",
              )
            end
          end

          on_success do
            if SiteSetting.upcoming_change_verbose_logging && SiteSetting.send(setting_name)
              Rails.logger.info(
                "#{log_prefix(site)} Successfully promoted '#{setting_name}' to enabled.",
              )
            end
          end
        end
      end
    end
  end
end
