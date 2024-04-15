# frozen_string_literal: true

class AddChatMentionNotifications < ActiveRecord::Migration[7.0]
  def change
    create_table :chat_mention_notifications, id: false do |t|
      t.integer :chat_mention_id, null: false
      t.integer :notification_id, null: false
    end

    add_index :chat_mention_notifications, %i[chat_mention_id]
    add_index :chat_mention_notifications, %i[notification_id], unique: true
  end
end
