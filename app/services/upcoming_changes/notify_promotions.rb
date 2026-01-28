# frozen_string_literal: true

# Notify admins of a specific upcoming change's promotion,
# which occurs when the change has reached the promotion status
# defined by SiteSetting.promote_upcoming_changes_on_status.
#
# Since the site setting is not actually changed in the database
# when an upcoming change is automatically promoted, we also
# fire off a DiscourseEvent that developers can listen to
# in 015-track-upcoming-change-toggle.rb.
#
# Admins will only be notified once for each upcoming change,
# both via a staff action log and a Notification in the UI.
class UpcomingChanges::NotifyPromotions
  include Service::Base

  model :changes_already_notified_about_promotion, optional: true
  model :admin_user_ids
  step :process_changes

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

  def process_changes(changes_already_notified_about_promotion:, admin_user_ids:)
    SiteSetting.upcoming_change_site_settings.each do |setting_name|
      unless UpcomingChanges.meets_or_exceeds_status?(
               setting_name,
               SiteSetting.promote_upcoming_changes_on_status.to_sym,
             )
        next
      end

      # We already told admins about the promotion.
      next if changes_already_notified_about_promotion.include?(setting_name)

      # The admin has manually opted out of the upcoming change.
      next if !UpcomingChanges.resolved_value(setting_name)

      # Though we aren't actually changing any site setting value, it's still
      # good to leave a paper trail for admins outside notification records.
      StaffActionLogger.new(Discourse.system_user).log_upcoming_change_toggle(
        setting_name,
        false,
        true,
        {
          context:
            I18n.t(
              "staff_action_logs.upcoming_changes.log_promoted",
              change_status: UpcomingChanges.change_status(setting_name).to_s.titleize,
              base_path: Discourse.base_path,
            ),
        },
      )

      notification_data = {
        upcoming_change_name: setting_name,
        upcoming_change_humanized_name: SiteSetting.humanized_name(setting_name),
      }.to_json

      records =
        admin_user_ids.map do |admin_id|
          {
            user_id: admin_id,
            notification_type: Notification.types[:upcoming_change_automatically_promoted],
            data: notification_data,
          }
        end

      Notification::Action::BulkCreate.call(records:)

      UpcomingChangeEvent.create!(
        event_type: :admins_notified_automatic_promotion,
        upcoming_change_name: setting_name,
        acting_user: Discourse.system_user,
      )

      DiscourseEvent.trigger(:upcoming_change_enabled, setting_name)
    end
  end
end
