# frozen_string_literal: true
class CopyChatMentionNotificationsNotificationIdValues < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute("DROP INDEX IF EXISTS chat_mention_notifications_tmp_migration_index")

    execute(<<~SQL)
      CREATE INDEX #{Rails.env.test? ? "" : "CONCURRENTLY"} chat_mention_notifications_tmp_migration_index ON chat_mention_notifications (notification_id)
      WHERE notification_id != new_notification_id
    SQL

    sql = <<~SQL
      UPDATE chat_mention_notifications
      SET new_notification_id = notification_id
      WHERE notification_id IN (
        SELECT
          notification_id
        FROM chat_mention_notifications
        WHERE notification_id != new_notification_id
        LIMIT 100000
      )
    SQL

    loop do
      count = execute(sql).cmd_tuples
      break if count == 0
    end

    execute("DROP INDEX IF EXISTS chat_mention_notifications_tmp_migration_index")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
