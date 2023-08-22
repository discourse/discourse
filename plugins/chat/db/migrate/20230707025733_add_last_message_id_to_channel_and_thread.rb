# frozen_string_literal: true

class AddLastMessageIdToChannelAndThread < ActiveRecord::Migration[7.0]
  def change
    add_column :chat_channels, :last_message_id, :bigint, null: true
    add_column :chat_threads, :last_message_id, :bigint, null: true

    add_index :chat_channels, :last_message_id
    add_index :chat_threads, :last_message_id
  end
end
