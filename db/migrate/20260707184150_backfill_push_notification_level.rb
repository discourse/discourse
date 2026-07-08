# frozen_string_literal: true

class BackfillPushNotificationLevel < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # push_notification_level enum: all: 0, chat_only: 1
  BATCH_SIZE = 30_000

  def up
    loop do
      count = DB.exec(<<~SQL, batch_size: BATCH_SIZE)
        WITH cte AS (
          SELECT user_id
          FROM user_options
          WHERE only_chat_push_notifications = true AND push_notification_level <> 1
          LIMIT :batch_size
        )
        UPDATE user_options
        SET push_notification_level = 1
        FROM cte
        WHERE user_options.user_id = cte.user_id
      SQL

      break if count == 0
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
