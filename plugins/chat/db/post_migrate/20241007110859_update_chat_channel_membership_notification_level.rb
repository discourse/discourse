# frozen_string_literal: true
class UpdateChatChannelMembershipNotificationLevel < ActiveRecord::Migration[7.1]
  def up
    batch_size = 10_000
    min_id, max_id = execute("SELECT MIN(id), MAX(id) FROM user_chat_channel_memberships")[0].values

    (min_id..max_id).step(batch_size) { |start_id| execute <<~SQL.squish } if min_id && max_id
      UPDATE user_chat_channel_memberships
      SET notification_level = mobile_notification_level
      WHERE id >= #{start_id} AND id < #{start_id + batch_size}
    SQL

    change_column_null :user_chat_channel_memberships, :notification_level, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
