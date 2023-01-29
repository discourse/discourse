# frozen_string_literal: true

class TruncateChatMessagesOverMaxLength < ActiveRecord::Migration[7.0]
  def up
    if table_exists?(:chat_messages)
      # 6000 is the default of the chat_maximum_message_length
      # site setting, its safe to do this because this will be
      # run the first time the setting is introduced.
      execute <<~SQL
        UPDATE chat_messages
        SET message = LEFT(message, 6000), cooked_version = NULL
        WHERE LENGTH(message) > 6000
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
