class AddDefaultViewToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :default_view, :string, null: true, limit: 50
  end
end
