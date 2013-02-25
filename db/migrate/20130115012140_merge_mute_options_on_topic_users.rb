class MergeMuteOptionsOnTopicUsers < ActiveRecord::Migration
  def change
    execute "update topic_users set notifications = 0 where notifications = 3"
    execute "update topic_users set notifications = 1 where notifications = 2"
    execute "update topic_users set notifications = 2 where notifications = 1"

    execute "update topic_users set notifications = 0 where muted_at is not null"
    rename_column :topic_users, :notifications, :notification_level
    remove_column :topic_users, :muted_at
  end
end
