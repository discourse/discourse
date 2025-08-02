# frozen_string_literal: true
class CreateIncomingChatWebhooks < ActiveRecord::Migration[6.1]
  def change
    create_table :incoming_chat_webhooks do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.integer :chat_channel_id, null: false
      t.string :username
      t.string :description
      t.string :emoji

      t.timestamps
    end

    add_index :incoming_chat_webhooks, %i[key chat_channel_id]
  end
end
