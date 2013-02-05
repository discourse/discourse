class AddStatsToCategories < ActiveRecord::Migration
  def change
    add_column :categories, :posts_year, :integer
    add_column :categories, :posts_month, :integer
    add_column :categories, :posts_week, :integer
  end
end
