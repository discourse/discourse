# frozen_string_literal: true

class CreateUserChatMessageStatuses < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_message_email_statuses do |t|
      t.integer :chat_message_id, null: false
      t.integer :user_id, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
