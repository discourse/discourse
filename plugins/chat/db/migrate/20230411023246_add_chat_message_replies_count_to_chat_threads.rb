# frozen_string_literal: true

class AddChatMessageRepliesCountToChatThreads < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_threads, :replies_count, :integer, null: false, default: 0
    add_index :chat_threads, :replies_count
  end
end
