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

  def self.verbose_log(site, level, message)
    return unless SiteSetting.upcoming_change_verbose_logging
    Rails.logger.public_send(level, "#{log_prefix(site)} #{message}")
  end

  def self.call
    RailsMultisite::ConnectionManagement.safe_each_connection do |site|
      next if !SiteSetting.enable_upcoming_changes

      verbose_log(site, :info, "Starting promotion check for upcoming changes.")

      if SiteSetting.upcoming_change_site_settings.empty?
        verbose_log(site, :info, "No upcoming changes present.")
        next
      end

      SiteSetting.upcoming_change_site_settings.each do |setting_name|
        UpcomingChanges::Promote.call(
          params: {
            setting_name:,
            promotion_status_threshold: SiteSetting.promote_upcoming_changes_on_status,
          },
          guardian: Guardian.new(Discourse.system_user),
        ) do |result|
          on_failed_policy(:meets_promotion_criteria) do
            verbose_log(
              site,
              :warn,
              "'#{setting_name}' did not meet promotion criteria. Current status is #{UpcomingChanges.change_status(setting_name)}, required status is #{SiteSetting.promote_upcoming_changes_on_status}.",
            )
          end

          on_failed_policy(:setting_not_modified) do
            verbose_log(
              site,
              :warn,
              "'#{setting_name}' has already been modified by an admin, skipping promotion.",
            )
          end

          on_failed_policy(:setting_not_already_enabled) do
            verbose_log(site, :warn, "'#{setting_name}' is already enabled, skipping promotion.")
          end

          on_failed_contract do |contract|
            verbose_log(
              site,
              :error,
              "Contract failure when promoting '#{setting_name}': #{contract.errors.full_messages.join(", ")}",
            )
          end

          on_failed_step(:toggle_upcoming_change) do
            verbose_log(
              site,
              :error,
              "Failed to promote '#{setting_name}' via toggle_upcoming_change, an unexpected error occurred.",
            )
          end

          on_failure do |error|
            verbose_log(
              site,
              :error,
              "Failed to promote '#{setting_name}', an unexpected error occurred.",
            )
          end

          on_success do
            verbose_log(site, :info, "Successfully promoted '#{setting_name}' to enabled.")
          end
        end
      end
    end
  end
end
