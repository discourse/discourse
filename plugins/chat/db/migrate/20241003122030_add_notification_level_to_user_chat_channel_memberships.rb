# frozen_string_literal: true
class AddNotificationLevelToUserChatChannelMemberships < ActiveRecord::Migration[7.1]
  def change
    remove_index :user_chat_channel_memberships, name: "user_chat_channel_memberships_index"
    add_column :user_chat_channel_memberships,
               :notification_level,
               :integer,
               default: 1,
               null: false

    execute <<~SQL
      UPDATE user_chat_channel_memberships
      SET notification_level = mobile_notification_level
    SQL

    add_index :user_chat_channel_memberships,
              %i[user_id chat_channel_id notification_level following],
              name: "user_chat_channel_memberships_index"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
