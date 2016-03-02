class RebuildDirectoryItemWithIndex < ActiveRecord::Migration
  def up
    remove_index :directory_items, [:period_type]
    execute "TRUNCATE TABLE directory_items RESTART IDENTITY"
    add_index :directory_items, [:period_type, :user_id], unique: true
  end

  def down
    remove_index :directory_items, [:period_type, :user_id]
    add_index :directory_items, [:period_type]
  end
end
