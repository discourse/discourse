class AddDefaultViewToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :default_view, :string, null: true, limit: 50
  end
end
