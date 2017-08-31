class AddForegroundColorToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :text_color, :string, limit: 6, null: false, default: 'FFFFFF'
  end
end
