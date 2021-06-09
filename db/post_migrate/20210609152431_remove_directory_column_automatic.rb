class RemoveDirectoryColumnAutomatic < ActiveRecord::Migration[6.1]
  def up
    remove_column :directory_columns, :automatic
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
