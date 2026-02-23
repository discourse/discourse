# frozen_string_literal: true

# Intended to be called from UpcomingChanges::Action::TrackStatusChanges, and
# UpcomingChanges::Action::TrackAddedChanges, not standalone.
#
# Send a notification to all admins that the upcoming change is available for
# them to opt-in to.
#
# This will either happen when the change is added, or when the status of the
# change is changed to the promotion status minus one.
class UpcomingChanges::Action::NotifyAdminsOfAvailableChange < Service::ActionBase
  include UpcomingChanges::NotificationDataMerger

  # The name of the upcoming change (site setting name)
  option :change_name

  # All admins that are not bots
  option :all_admins

  def call
    notify_admins
    create_event
    log_action
    true
  end

  private

  def notify_admins
    existing_notifications =
      Notification.where(
        notification_type: Notification.types[:upcoming_change_available],
        user_id: all_admins.map(&:id),
        read: false,
      ).to_a
    existing_by_user = existing_notifications.index_by(&:user_id)

    records =
      all_admins.map do |admin|
        {
          user_id: admin.id,
          notification_type: Notification.types[:upcoming_change_available],
          data: merge_change_data(existing_by_user[admin.id], change_name).to_json,
        }
      end

    Notification.transaction do
      if existing_notifications.any?
        Notification.where(id: existing_notifications.map(&:id)).delete_all
      end
      Notification::Action::BulkCreate.call(records:)
    end
  end

  def create_event
    UpcomingChangeEvent.create!(
      event_type: :admins_notified_available_change,
      upcoming_change_name: change_name,
    )
  end

  def log_action
    StaffActionLogger.new(Discourse.system_user).log_upcoming_change_available(change_name)
  end
end
