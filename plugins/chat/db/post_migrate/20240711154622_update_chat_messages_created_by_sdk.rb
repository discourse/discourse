# frozen_string_literal: true
class UpdateChatMessagesCreatedBySdk < ActiveRecord::Migration[7.1]
  def up
    change_column_default :chat_messages, :created_by_sdk, false

    if DB.query_single("SELECT 1 FROM chat_messages WHERE created_by_sdk IS NULL LIMIT 1").first
      batch_size = 10_000
      min_id = DB.query_single("SELECT MIN(id) FROM chat_messages").first.to_i
      max_id = DB.query_single("SELECT MAX(id) FROM chat_messages").first.to_i
      while max_id >= min_id
        DB.exec(
          "UPDATE chat_messages SET created_by_sdk = false WHERE id > #{max_id - batch_size} AND id <= #{max_id}",
        )
        max_id -= batch_size
      end
    end

    change_column_null :chat_messages, :created_by_sdk, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
