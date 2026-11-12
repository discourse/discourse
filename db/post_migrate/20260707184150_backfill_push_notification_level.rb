# frozen_string_literal: true

class BackfillPushNotificationLevel < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # push_notification_level enum: none: 0, all: 1, chat_only: 2
  BATCH_SIZE = 30_000

  def up
    # `only_chat_push_notifications` is a chat-plugin column; skip when it isn't
    # present (e.g. the chat plugin is absent, or the migrations-tooling core-only
    # schema) so this core migration never references a missing column.
    return unless column_exists?(:user_options, :only_chat_push_notifications)

    loop do
      count = DB.exec(<<~SQL, batch_size: BATCH_SIZE)
        WITH cte AS (
          SELECT user_id
          FROM user_options
          WHERE only_chat_push_notifications = true AND push_notification_level <> 2
          LIMIT :batch_size
        )
        UPDATE user_options
        SET push_notification_level = 2
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
