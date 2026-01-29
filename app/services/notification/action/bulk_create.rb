# frozen_string_literal: true

# Bulk creates notifications using insert_all! for efficiency, then manually
# handles the after_commit callbacks that would normally run on individual creates:
# - MessageBus notification state publishing per user
# - Email processing via NotificationEmailer
# - DiscourseEvent.trigger(:notification_created, notification)
#
# @example
#   Notification::Action::BulkCreate.call(
#     records: [
#       { user_id: 1, notification_type: Notification.types[:custom], data: "{}".to_json },
#       { user_id: 2, notification_type: Notification.types[:custom], data: "{}".to_json },
#     ]
#   )
#
class Notification::Action::BulkCreate < Service::ActionBase
  # Array of notification attribute hashes.
  # Required keys: :user_id, :notification_type, :data
  # Optional keys: :topic_id, :post_number, :high_priority
  option :records

  # Skip email sending for all notifications
  option :skip_send_email, default: -> { false }

  def call
    return [] if records.blank?

    insert_notifications
    publish_notification_states
    post_process_notifications

    @notification_ids
  end

  private

  def insert_notifications
    now = Time.zone.now

    rows =
      records.map do |record|
        {
          user_id: record[:user_id],
          notification_type: record[:notification_type],
          data: record[:data],
          topic_id: record[:topic_id],
          post_number: record[:post_number],
          high_priority:
            record[:high_priority] ||
              Notification.high_priority_types.include?(record[:notification_type]),
          read: false,
          created_at: now,
          updated_at: now,
        }
      end

    result = Notification.insert_all!(rows, returning: %i[id user_id])
    @notification_ids = result.rows.map(&:first)
    @user_ids_from_insert = result.rows.map(&:second).uniq
  end

  def publish_notification_states
    User.where(id: @user_ids_from_insert).find_each(&:publish_notifications_state)
  end

  def post_process_notifications
    Notification
      .where(id: @notification_ids)
      .includes(:user)
      .find_each do |notification|
        if !skip_send_email
          if notification.user.do_not_disturb?
            ShelvedNotification.create(notification_id: notification.id)
          else
            NotificationEmailer.process_notification(notification)
          end
        end

        DiscourseEvent.trigger(:notification_created, notification)
      end
  end
end
