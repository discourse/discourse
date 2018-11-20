class AddExcerptToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :excerpt, :string, limit: 250
  end
end
