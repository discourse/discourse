class RenameSeenNotificaitonId < ActiveRecord::Migration
  def up
    rename_column :users, :seen_notificaiton_id, :seen_notification_id
  end

  def down
    rename_column :users, :seen_notification_id, :seen_notificaiton_id
  end
end
