# frozen_string_literal: true
class AddNotificationLevelToUserChatChannelMemberships < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS user_chat_channel_memberships_index
    SQL

    add_column :user_chat_channel_memberships, :notification_level, :integer, default: 1

    execute <<~SQL
      CREATE INDEX CONCURRENTLY user_chat_channel_memberships_index ON user_chat_channel_memberships using btree (user_id, chat_channel_id, notification_level, following)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
