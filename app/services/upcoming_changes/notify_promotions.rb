# frozen_string_literal: true

# Notify admins of all upcoming changes' promotions,
# which is called from the Jobs::Scheduled::CheckUpcomingChanges job.
class UpcomingChanges::NotifyPromotions
  include Service::Base

  model :changes_already_notified_about_promotion, optional: true
  model :changes_already_promoted, optional: true
  model :admin_user_ids
  model :change_notification_statuses

  private

  def fetch_changes_already_notified_about_promotion
    UpcomingChangeEvent.change_names_with_event(:admins_notified_automatic_promotion)
  end

  def fetch_changes_already_promoted
    UpcomingChangeEvent.change_names_with_event(:automatically_promoted)
  end

  def fetch_admin_user_ids
    User.admin_ids
  end

  def fetch_change_notification_statuses(
    changes_already_notified_about_promotion:,
    changes_already_promoted:,
    admin_user_ids:
  )
    SiteSetting.upcoming_change_site_settings.index_with do |setting_name|
      status_hash = {}

      # NOTE: Make sure to handle additional error_key values in the
      # CheckUpcomingChanges job's verbose_log.
      UpcomingChanges::NotifyPromotion.call(
        params: {
          setting_name: setting_name.to_sym,
          changes_already_notified_about_promotion:,
          changes_already_promoted:,
          admin_user_ids:,
        },
        guardian: Discourse.system_user.guardian,
      ) do |result|
        status_hash[:success] = result.success?

        on_failed_policy(:setting_is_available) do |policy|
          status_hash[:error] = "Setting #{setting_name} is not available"
          status_hash[:error_key] = :setting_not_available
        end

        on_failed_policy(:should_notify_admins) do |policy|
          status_hash[:error] = "Setting #{setting_name} should not notify admins about promotion"
          status_hash[:error_key] = :should_not_notify_admins
        end

        on_failed_policy(:change_should_be_displayed) do |policy|
          status_hash[
            :error
          ] = "Setting #{setting_name} is not displayed on this site, skipping promotion notification"
          status_hash[:error_key] = :should_not_be_displayed
        end

        on_failed_policy(:meets_or_exceeds_status) do |policy|
          status_hash[
            :error
          ] = "Setting #{setting_name} does not meet or exceed the promotion status"
          status_hash[:error_key] = :does_not_meet_or_exceed_promotion_status
        end

        on_failed_policy(:promotion_not_already_handled) do |policy|
          status_hash[:error] = "Setting #{setting_name} has already been promoted"
          status_hash[:error_key] = :already_promoted
        end

        on_failed_policy(:admin_has_not_manually_toggled) do |policy|
          status_hash[
            :error
          ] = "Setting #{setting_name} has been manually opted in or out by an admin, we did not notify admins about promotion"
          status_hash[:error_key] = :already_manually_toggled
        end

        on_exceptions do |exception|
          status_hash[:error] = exception.message
          status_hash[:error_key] = :unexpected_error
          status_hash[:backtrace] = exception.backtrace
        end
      end

      status_hash
    end
  end
end
