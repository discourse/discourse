class OopsUnwatchABoatOfWatchedStuff < ActiveRecord::Migration
  def change
    execute 'update topic_users set notification_level = 1 where notifications_reason_id is null and notification_level = 2'
  end
end
