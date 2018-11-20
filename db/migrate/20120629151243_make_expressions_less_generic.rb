class MakeExpressionsLessGeneric < ActiveRecord::Migration[4.2]
  def up
    rename_column :expressions, :parent_id, :post_id
    rename_column :expressions, :expression_type_id, :expression_index
    remove_column :expressions, :parent_type

    add_index :expressions, [:post_id, :expression_index, :user_id], unique: true, name: 'unique_by_user'
  end

  def down
    rename_column :expressions, :post_id, :parent_id
    rename_column :expressions, :expression_index, :expression_type_id
    add_column :expressions, :parent_type, :string, null: true
  end

end
