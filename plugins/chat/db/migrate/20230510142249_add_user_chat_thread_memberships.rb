# frozen_string_literal: true

class AddUserChatThreadMemberships < ActiveRecord::Migration[7.0]
  def change
    create_table :user_chat_thread_memberships do |t|
      t.bigint :user_id, null: false
      t.bigint :thread_id, null: false
      t.bigint :last_read_message_id
      t.integer :notification_level, default: 2, null: false # default to tracking
      t.timestamps
    end

    add_index :user_chat_thread_memberships,
              %i[user_id thread_id],
              unique: true,
              name: "user_chat_thread_unique_memberships"
  end
end
