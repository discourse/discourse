class DropUnusedTables < ActiveRecord::Migration[5.1]
  def up
    drop_table :category_featured_users
    drop_table :versions
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
