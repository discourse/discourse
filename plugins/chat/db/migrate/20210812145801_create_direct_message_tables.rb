# frozen_string_literal: true

class CreateDirectMessageTables < ActiveRecord::Migration[6.1]
  def change
    create_table :direct_message_channels do |t|
      t.timestamps
    end

    create_table :direct_message_users do |t|
      t.integer :direct_message_channel_id, null: false
      t.integer :user_id, null: false
      t.timestamps
    end

    add_index :direct_message_users,
              %i[direct_message_channel_id user_id],
              unique: true,
              name: "direct_message_users_index"
  end
end
