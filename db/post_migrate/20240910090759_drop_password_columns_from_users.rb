# frozen_string_literal: true
class DropPasswordColumnsFromUsers < ActiveRecord::Migration[7.1]
  DROPPED_COLUMNS ||= { users: %i[password_hash salt password_algorithm] }

  def up
    # remove invalid triggers/functions dependent on the columns to be dropped
    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS users_password_sync_on_delete_password ON users;
      DROP FUNCTION IF EXISTS delete_user_password;
      DROP TRIGGER IF EXISTS users_password_sync ON users;
      DROP FUNCTION IF EXISTS mirror_user_password_data;
    SQL

    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
