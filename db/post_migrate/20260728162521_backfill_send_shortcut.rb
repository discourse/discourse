# frozen_string_literal: true

class BackfillSendShortcut < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  BATCH_SIZE = 30_000

  def up
    # `chat_send_shortcut` is a chat-plugin column; skip when it isn't present
    # (e.g. the chat plugin is absent, or the migrations-tooling core-only
    # schema) so this core migration never references a missing column.
    return unless column_exists?(:user_options, :chat_send_shortcut)

    loop do
      count = DB.exec(<<~SQL, batch_size: BATCH_SIZE)
        WITH cte AS (
          SELECT user_id
          FROM user_options
          WHERE chat_send_shortcut <> 0 AND send_shortcut <> chat_send_shortcut
          LIMIT :batch_size
        )
        UPDATE user_options
        SET send_shortcut = user_options.chat_send_shortcut
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
