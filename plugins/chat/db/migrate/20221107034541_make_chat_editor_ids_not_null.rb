# frozen_string_literal: true

class MakeChatEditorIdsNotNull < ActiveRecord::Migration[7.0]
  def change
    DB.exec("UPDATE chat_messages SET last_editor_id = user_id")
    DB.exec(<<~SQL)
      UPDATE chat_message_revisions cmr
      SET user_id = cm.user_id
      FROM chat_messages AS cm
      WHERE cmr.chat_message_id = cm.id
    SQL

    change_column_null :chat_messages, :last_editor_id, false
    change_column_null :chat_message_revisions, :user_id, false
  end
end
