class AddExcerptToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :excerpt, :string, limit: 250
  end
end
