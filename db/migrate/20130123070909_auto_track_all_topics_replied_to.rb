# frozen_string_literal: true

class AutoTrackAllTopicsRepliedTo < ActiveRecord::Migration[4.2]
  def up
    execute 'update topic_users set notification_level = 2, notifications_reason_id = 4
      from posts p
      where
        notification_level = 1 and
        notifications_reason_id is null and
        p.topic_id = topic_users.topic_id and
        p.user_id = topic_users.user_id
    '
  end

  def down
  end
end
