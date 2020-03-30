# frozen_string_literal: true

class DropOldUnreadPmNotificationIndices < ActiveRecord::Migration[6.0]
  def up
    DB.exec("DROP INDEX IF EXISTS index_notifications_on_user_id_and_id")
    DB.exec("DROP INDEX IF EXISTS index_notifications_on_read_or_n_type")
  end

  def down
    add_index :notifications, [:user_id, :id], unique: true, where: 'notification_type = 6 AND NOT read'
    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY index_notifications_on_read_or_n_type
      ON notifications(user_id, id DESC, read, topic_id)
      WHERE read or notification_type <> 6
    SQL
  end
end
