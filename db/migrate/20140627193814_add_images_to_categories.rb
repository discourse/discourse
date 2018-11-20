class AddImagesToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :logo_url, :string
    add_column :categories, :background_url, :string
  end
end
