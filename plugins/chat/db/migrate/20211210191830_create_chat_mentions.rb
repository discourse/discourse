# frozen_string_literal: true
class CreateChatMentions < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_mentions do |t|
      t.integer :chat_message_id, null: false
      t.integer :user_id, null: false
      t.integer :notification_id, null: false
      t.timestamps
    end

    add_index :chat_mentions,
              %i[chat_message_id user_id notification_id],
              unique: true,
              name: "chat_mentions_index"
  end
end
