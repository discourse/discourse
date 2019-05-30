# frozen_string_literal: true

class FixSeenNotificationIds < ActiveRecord::Migration[4.2]
  def up

    # There was an error where `seen_notification_id` was being updated incorrectly.
    # This tries to fix some of the bad data.
    execute "UPDATE users SET
              seen_notification_id = COALESCE((SELECT MAX(notifications.id)
                                               FROM notifications
                                               WHERE user_id = users.id AND created_at <= users.last_seen_at), 0)"
  end

  def down
  end
end
