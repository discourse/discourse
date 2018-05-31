class RenameColumn < ActiveRecord::Migration[5.1]
  def up
    rename_column :users, :username, :username1
  end

  def down
    raise "not tested"
  end
end
