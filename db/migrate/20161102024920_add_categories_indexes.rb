class AddCategoriesIndexes < ActiveRecord::Migration
  def change
    add_index :categories, :logo_url
    add_index :categories, :background_url
  end
end
