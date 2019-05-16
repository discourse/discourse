# frozen_string_literal: true

class AddStatsToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :posts_year, :integer
    add_column :categories, :posts_month, :integer
    add_column :categories, :posts_week, :integer
  end
end
