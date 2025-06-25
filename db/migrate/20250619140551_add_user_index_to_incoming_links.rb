# frozen_string_literal: true
class AddUserIndexToIncomingLinks < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
      index_incoming_links_on_user_id ON incoming_links(user_id) WHERE user_id IS NOT NULL
    SQL

    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS
      index_incoming_links_on_current_user_id ON incoming_links(current_user_id) WHERE current_user_id IS NOT NULL
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_incoming_links_on_user_id
    SQL

    execute <<~SQL
      DROP INDEX IF EXISTS index_incoming_links_on_current_user_id
    SQL
  end
end
