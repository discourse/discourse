# frozen_string_literal: true
class CreateUserChatChannelMembership < ActiveRecord::Migration[6.1]
  def change
    create_table :user_chat_channel_memberships do |t|
      t.integer :user_id, null: false
      t.integer :chat_channel_id, null: false
      t.integer :last_read_message_id
      t.boolean :following, default: false, null: false # membership on/off switch
      t.boolean :muted, default: false, null: false
      t.integer :desktop_notification_level, default: 1, null: false
      t.integer :mobile_notification_level, default: 1, null: false
      t.timestamps
    end

    add_index :user_chat_channel_memberships,
              %i[
                user_id
                chat_channel_id
                desktop_notification_level
                mobile_notification_level
                following
              ],
              name: "user_chat_channel_memberships_index"

    add_index :user_chat_channel_memberships,
              %i[user_id chat_channel_id],
              unique: true,
              name: "user_chat_channel_unique_memberships"
  end
end
