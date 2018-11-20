class AddParentCategoryIdToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :parent_category_id, :integer
  end
end
