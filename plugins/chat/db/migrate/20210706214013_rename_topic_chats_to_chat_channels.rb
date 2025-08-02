# frozen_string_literal: true

class RenameTopicChatsToChatChannels < ActiveRecord::Migration[6.1]
  def up
    begin
      Migration::SafeMigrate.disable!

      # Trash all existing chat info
      DB.exec("DELETE FROM topic_chats")
      DB.exec("DELETE FROM topic_chat_messages")

      # topic_chat table changes
      rename_table :topic_chats, :chat_channels
      rename_column :chat_channels, :topic_id, :chatable_id
      change_column :chat_channels, :chatable_id, :integer, unique: false
      add_column :chat_channels, :chatable_type, :string
      change_column_null :chat_channels, :chatable_type, false
      add_index :chat_channels, %i[chatable_id chatable_type]

      # topic_chat_messages table changes
      rename_table :topic_chat_messages, :chat_messages
      rename_column :chat_messages, :topic_id, :chat_channel_id
      change_column_null :chat_messages, :post_id, true # Don't require post_id
    ensure
      Migration::SafeMigrate.enable!
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
