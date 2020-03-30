# frozen_string_literal: true

class AddPriorityColumnToNotifications < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!
  def up
    if !column_exists?(:notifications, :priority)
      add_column :notifications, :priority, :integer, default: nil
    end

    # type 6 = private message, 24 = bookmark reminder
    # priority 0 = low, 1 = normal, 2 = high
    execute <<~SQL
      UPDATE notifications SET priority = 2 WHERE notification_type IN (6, 24);
      UPDATE notifications SET priority = 1 WHERE notification_type NOT IN (6, 24);
    SQL

    execute <<~SQL
      ALTER TABLE notifications ALTER COLUMN priority SET DEFAULT 1;
      ALTER TABLE notifications ALTER COLUMN priority SET NOT NULL;
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_notifications_unread_normal_priority ON notifications(user_id, priority) WHERE NOT read AND priority = 1;
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_notifications_read_or_not_high_priority ON notifications(user_id, id DESC, read, topic_id) WHERE (read OR (priority <> 2));
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_notifications_unread_high_priority ON notifications(user_id, priority) WHERE NOT read AND priority = 2;
    SQL

    execute <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS index_notifications_unique_unread_high_priority ON notifications(user_id, id) WHERE NOT read AND priority = 2;
    SQL
  end

  def down
    DB.exec("ALTER TABLE notifications DROP COLUMN IF EXISTS priority")
  end
end
