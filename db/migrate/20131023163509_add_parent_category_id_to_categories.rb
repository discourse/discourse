class AddParentCategoryIdToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :parent_category_id, :integer
  end
end

