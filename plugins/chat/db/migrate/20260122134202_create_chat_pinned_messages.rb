# frozen_string_literal: true

class CreateChatPinnedMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :chat_pinned_messages do |t|
      t.bigint :chat_message_id, null: false
      t.bigint :chat_channel_id, null: false
      t.bigint :pinned_by_id, null: false
      t.timestamps
    end

    add_index :chat_pinned_messages, :chat_message_id, unique: true
    add_index :chat_pinned_messages,
              %i[chat_channel_id created_at],
              order: {
                created_at: :desc,
              },
              name: "idx_chat_pinned_messages_channel_created"
  end
end
