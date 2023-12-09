# frozen_string_literal: true

class AddOpenThreadingEnabledCategoryChannelIndex < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # to keep
    execute <<~SQL
    DROP INDEX CONCURRENTLY IF EXISTS idx_user_chat_thread_memberships_on_thread_id_user_id
    SQL

    execute <<~SQL
    CREATE INDEX idx_user_chat_thread_memberships_on_thread_id_user_id
    ON user_chat_thread_memberships (thread_id, user_id);
    SQL
  end

  def down
    execute <<~SQL
    DROP INDEX CONCURRENTLY IF EXISTS index_open_threading_enabled_category
    SQL
  end
end
