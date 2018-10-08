class RenameTable < ActiveRecord::Migration[5.1]
  def up
    rename_table :users, :persons
  end

  def down
    raise "not tested"
  end
end
