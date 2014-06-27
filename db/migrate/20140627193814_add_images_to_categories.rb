class AddImagesToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :logo_url, :string
    add_column :categories, :background_url, :string
  end
end
