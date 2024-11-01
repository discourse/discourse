# frozen_string_literal: true

class AlterIgnoredUsersIdsToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :ignored_users, :ignored_user_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
