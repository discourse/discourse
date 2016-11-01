class AddSortFieldsToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :sort_order, :string
    add_column :categories, :sort_ascending, :boolean
  end
end
