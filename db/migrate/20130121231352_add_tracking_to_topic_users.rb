class AddTrackingToTopicUsers < ActiveRecord::Migration[4.2]
  def up
    execute 'update topic_users set notification_level = 3 where notification_level = 2'
  end
  def down
    execute 'update topic_users set notification_level = 2 where notification_level = 3'
  end
end
