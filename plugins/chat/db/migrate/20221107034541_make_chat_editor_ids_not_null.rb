# frozen_string_literal: true

class MakeChatEditorIdsNotNull < ActiveRecord::Migration[7.0]
  def change
    change_column_null :chat_messages, :last_editor_id, false
    change_column_null :chat_message_revisions, :user_id, false
  end
end
