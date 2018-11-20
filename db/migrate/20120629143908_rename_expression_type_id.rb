class RenameExpressionTypeId < ActiveRecord::Migration[4.2]

  def up
    add_column :expression_types, :expression_index, :integer
    execute "UPDATE expression_types SET expression_index = id"
    remove_column :expression_types, :id

    add_index :expression_types, [:site_id, :expression_index], unique: true
  end

  def down
    add_column :expression_types, :id, :integer
    execute "UPDATE expression_types SET id = expression_index"
    remove_column :expression_types, :expression_index
  end
end
