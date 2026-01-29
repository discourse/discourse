# frozen_string_literal: true

# Notify admins of all upcoming changes' promotions,
# which is called from the Jobs::Scheduled::CheckUpcomingChanges job.
class UpcomingChanges::NotifyPromotions
  include Service::Base

  model :changes_already_notified_about_promotion, optional: true
  model :admin_user_ids
  model :change_notification_statuses

  private

  def fetch_changes_already_notified_about_promotion
    UpcomingChangeEvent
      .where(
        upcoming_change_name: SiteSetting.upcoming_change_site_settings,
        event_type: :admins_notified_automatic_promotion,
      )
      .pluck(:upcoming_change_name)
      .map(&:to_sym)
  end

  def fetch_admin_user_ids
    User.human_users.admins.pluck(:id)
  end

  def fetch_change_notification_statuses(changes_already_notified_about_promotion:, admin_user_ids:)
    SiteSetting.upcoming_change_site_settings.index_with do |setting_name|
      status_hash = {}

      UpcomingChanges::NotifyPromotion.call(
        params: {
          setting_name: setting_name.to_sym,
          changes_already_notified_about_promotion:,
          admin_user_ids:,
        },
        guardian: Discourse.system_user.guardian,
      ) do |result|
        status_hash[:success] = result.success?

        on_failed_policy(:setting_is_available) do |policy|
          status_hash[:error] = "Setting #{setting_name} is not available"
        end

        on_failed_policy(:meets_or_exceeds_status) do |policy|
          status_hash[
            :error
          ] = "Setting #{setting_name} does not meet or exceed the promotion status"
        end

        on_failed_policy(:change_has_not_already_been_notified_about_promotion) do |policy|
          status_hash[
            :error
          ] = "Setting #{setting_name} has already notified admins about promotion"
        end

        on_failed_policy(:admin_has_not_manually_opted_out) do |policy|
          status_hash[:error] = "Setting #{setting_name} has been manually opted out by an admin"
        end

        on_exceptions do |exception|
          status_hash[:error] = exception.message
          status_hash[:backtrace] = Service.filter_backtrace(exception.backtrace)
        end
      end

      status_hash
    end
  end
end
