class DontAutoMutoTopics < ActiveRecord::Migration[4.2]
  def change
    # muting all new topics was a mistake, revert it
    execute 'DELETE FROM topic_users WHERE notification_level = 0 and notifications_reason_id =7 AND first_visited_at IS NULL'

    execute 'UPDATE topic_users SET notification_level = 1,
                                    notifications_reason_id = NULL
            WHERE notification_level = 0 AND notifications_reason_id =7'
  end
end
