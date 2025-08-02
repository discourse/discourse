# frozen_string_literal: true
class CreateChatWebhookEvents < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_webhook_events do |t|
      t.integer :chat_message_id, null: false
      t.integer :incoming_chat_webhook_id, null: false
      t.timestamps
    end

    add_index :chat_webhook_events,
              %i[chat_message_id incoming_chat_webhook_id],
              unique: true,
              name: "chat_webhook_events_index"
  end
end
