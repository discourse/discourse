class DropUnusedTables < ActiveRecord::Migration[5.1]
  def up
    # Delayed drop of tables "category_featured_users" and "versions"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
