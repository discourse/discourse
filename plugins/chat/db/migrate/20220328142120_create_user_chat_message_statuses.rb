# frozen_string_literal: true

class CreateUserChatMessageStatuses < ActiveRecord::Migration[6.1]
  def change
    create_table :chat_message_email_statuses do |t|
      t.integer :chat_message_id, null: false
      t.integer :user_id, null: false
      t.integer :status, null: false, default: 0
      t.integer :type, null: false
      t.timestamps
    end

    add_index :chat_message_email_statuses,
              %i[user_id chat_message_id],
              name: "chat_message_email_status_user_message_index"
    add_index :chat_message_email_statuses, :status

    add_column :user_options, :chat_email_frequency, :integer, default: 1, null: false
    add_column :user_options, :last_emailed_for_chat, :datetime, null: true
  end
end
