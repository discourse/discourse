class AddNameLowerToCategories < ActiveRecord::Migration

  def up
    add_column :categories, :name_lower, :string, limit: 50
    execute "update categories set name_lower = lower(name)"
    change_column :categories, :name_lower, :string, limit: 50, null:false
  end

  def down
    remove_column :categories, :name_lower
  end

end
