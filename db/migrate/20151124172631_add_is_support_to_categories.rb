class AddIsSupportToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :is_support, :boolean, default: false, null: false
  end
end
