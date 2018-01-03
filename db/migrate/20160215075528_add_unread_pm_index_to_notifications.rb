class AddUnreadPmIndexToNotifications < ActiveRecord::Migration[4.2]
  def change
    # create index idxtmp on notifications(user_id, id) where notification_type = 6 AND NOT read
    add_index :notifications, [:user_id, :id], unique: true, where: 'notification_type = 6 AND NOT read'
  end
end
