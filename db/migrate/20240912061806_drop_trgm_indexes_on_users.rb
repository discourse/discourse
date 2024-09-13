# frozen_string_literal: true
class DropTrgmIndexesOnUsers < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      DROP INDEX IF EXISTS index_users_on_username_lower_trgm;
      DROP INDEX IF EXISTS index_users_on_name_trgm;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
