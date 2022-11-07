# frozen_string_literal: true

class BackfillEditingUserIdsForChatMessagesAndRevisions < ActiveRecord::Migration[7.0]
  def up
    DB.exec("UPDATE chat_messages SET last_editor_id = user_id")
    DB.exec(<<~SQL)
      UPDATE chat_message_revisions cmr
      SET user_id = cm.user_id
      FROM chat_messages AS cm
      WHERE cmr.chat_message_id = cm.id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
