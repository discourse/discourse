class AddForegroundColorToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :text_color, :string, limit: 6, null: false, default: 'FFFFFF'
  end
end
