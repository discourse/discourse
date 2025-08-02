# frozen_string_literal: true

class AddHighPriorityColumnToNotifications < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!
  def up
    if !column_exists?(:notifications, :high_priority)
      add_column :notifications, :high_priority, :boolean, default: nil
    end

    # type 6 = private message, 24 = bookmark reminder
    # priority 0 = low, 1 = normal, 2 = high
    if column_exists?(:notifications, :high_priority)
      execute <<~SQL
        UPDATE notifications SET high_priority = TRUE WHERE notification_type IN (6, 24);
      SQL

      execute <<~SQL
        UPDATE notifications SET high_priority = FALSE WHERE notification_type NOT IN (6, 24);
      SQL

      execute <<~SQL
        ALTER TABLE notifications ALTER COLUMN high_priority SET DEFAULT FALSE;
      SQL

      execute <<~SQL
        UPDATE notifications SET high_priority = FALSE WHERE high_priority IS NULL;
      SQL

      execute <<~SQL
        ALTER TABLE notifications ALTER COLUMN high_priority SET NOT NULL;
      SQL
    end

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_notifications_read_or_not_high_priority ON notifications(user_id, id DESC, read, topic_id) WHERE (read OR (high_priority = FALSE));
    SQL

    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS index_notifications_unique_unread_high_priority ON notifications(user_id, id) WHERE NOT read AND high_priority = TRUE;
    SQL
  end

  def down
    DB.exec("ALTER TABLE notifications DROP COLUMN IF EXISTS high_priority")
  end
end
