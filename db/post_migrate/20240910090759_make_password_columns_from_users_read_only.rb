# frozen_string_literal: true
class MakePasswordColumnsFromUsersReadOnly < ActiveRecord::Migration[7.1]
  def up
    # remove invalid triggers/functions dependent on the columns to be dropped
    execute <<~SQL
      DROP TRIGGER IF EXISTS users_password_sync_on_delete_password ON users;
    SQL

    execute <<~SQL
      DROP FUNCTION IF EXISTS delete_user_password;
    SQL

    execute <<~SQL
      DROP TRIGGER IF EXISTS users_password_sync ON users;
    SQL

    execute <<~SQL
      DROP FUNCTION IF EXISTS mirror_user_password_data;
    SQL

    %i[password_hash salt password_algorithm].each do |column|
      Migration::ColumnDropper.mark_readonly(:users, column)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
