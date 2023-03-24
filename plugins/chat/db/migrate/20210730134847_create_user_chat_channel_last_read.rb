# frozen_string_literal: true

class CreateUserChatChannelLastRead < ActiveRecord::Migration[6.1]
  def change
    create_table :user_chat_channel_last_reads do |t|
      t.integer :chat_channel_id, null: false
      t.integer :chat_message_id, null: true # Can be null if user hasn't opened the channel
      t.integer :user_id, null: false
    end

    add_index :user_chat_channel_last_reads,
              %i[chat_channel_id user_id],
              unique: true,
              name: "user_chat_channel_reads_index"
  end
end
