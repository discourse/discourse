# frozen_string_literal: true

class AddUserChatThreadMembershipsOnThreadIdUserIdIndex < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
    DROP INDEX CONCURRENTLY IF EXISTS idx_user_chat_thread_memberships_on_thread_id_user_id
    SQL

    execute <<~SQL
    CREATE INDEX CONCURRENTLY idx_user_chat_thread_memberships_on_thread_id_user_id
    ON user_chat_thread_memberships (thread_id, user_id);
    SQL
  end

  def down
    execute <<~SQL
    DROP INDEX CONCURRENTLY IF EXISTS idx_user_chat_thread_memberships_on_thread_id_user_id
    SQL
  end
end
