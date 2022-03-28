# frozen_string_literal: true

class CreateChatEmailConsolidations < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_email_consolidations do |t|
      t.integer :chat_message_id, null: false
      t.integer :user_id, null: false
      t.boolean :processed, null: false, default: false
      t.timestamps
    end
  end
end
