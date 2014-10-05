class ChangeCategoryUniqunessContstraint < ActiveRecord::Migration
  def change
    remove_index :categories, name: 'index_categories_on_name'
    add_index :categories, [:parent_category_id, :name], unique: true
  end
end
