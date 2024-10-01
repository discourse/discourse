# frozen_string_literal: true
class DropTrgmIndexesOnUsers < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_users_on_username_lower_trgm;
    SQL

    execute <<~SQL
      DROP INDEX CONCURRENTLY IF EXISTS index_users_on_name_trgm;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
