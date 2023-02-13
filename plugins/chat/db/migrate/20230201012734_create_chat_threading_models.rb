# frozen_string_literal: true

class CreateChatThreadingModels < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_threads do |t|
      t.bigint :channel_id, null: false
      t.bigint :original_message_id, null: false
      t.bigint :original_message_user_id, null: false
      t.integer :status, null: false, default: 0
      t.string :title, null: true

      t.timestamps
    end

    add_index :chat_threads, :channel_id
    add_index :chat_threads, :original_message_id
    add_index :chat_threads, :original_message_user_id
    add_index :chat_threads, :status
    add_index :chat_threads, %i[channel_id status]

    add_column :chat_messages, :thread_id, :bigint, null: true
    add_index :chat_messages, :thread_id
  end
end
