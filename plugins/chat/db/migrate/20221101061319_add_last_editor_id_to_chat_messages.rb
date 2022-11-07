# frozen_string_literal: true

class AddLastEditorIdToChatMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_messages, :last_editor_id, :integer
    add_column :chat_message_revisions, :user_id, :integer

    add_index :chat_messages, :last_editor_id
    add_index :chat_message_revisions, :user_id
  end
end
