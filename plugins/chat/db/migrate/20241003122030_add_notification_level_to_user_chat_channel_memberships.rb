# frozen_string_literal: true
class AddNotificationLevelToUserChatChannelMemberships < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS user_chat_channel_memberships_index
    SQL

    add_column :user_chat_channel_memberships, :notification_level, :integer, null: true

    batch_size = 10_000
    min_id, max_id = execute("SELECT MIN(id), MAX(id) FROM user_chat_channel_memberships")[0].values

    (min_id..max_id).step(batch_size) { |start_id| execute <<~SQL.squish } if min_id && max_id
      UPDATE user_chat_channel_memberships
      SET notification_level = mobile_notification_level
      WHERE id >= #{start_id} AND id < #{start_id + batch_size}
    SQL

    change_column_default :user_chat_channel_memberships, :notification_level, 1
    change_column_null :user_chat_channel_memberships, :notification_level, false

    execute <<~SQL
      CREATE INDEX CONCURRENTLY user_chat_channel_memberships_index ON user_chat_channel_memberships using btree (user_id, chat_channel_id, notification_level, following)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
