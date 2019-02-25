class RemoveColumn < ActiveRecord::Migration[5.1]
  def up
    remove_column :users, :username
  end

  def down
    raise "not tested"
  end
end
