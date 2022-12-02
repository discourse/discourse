# frozen_string_literal: true

class AddChatMessageCountToChatChannels < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_channels, :chat_message_count, :integer, null: false, default: 0
    add_index :chat_channels, :chat_message_count
  end
end
