class DropUsersTable < ActiveRecord::Migration[5.2]
  def up
    drop_table :users
    raise ActiveRecord::Rollback
  end

  def down
    raise "not tested"
  end
end
