# frozen_string_literal: true

class AddThreadCountsToCategories < ActiveRecord::Migration[4.2]
  def change
    add_column :categories, :threads_year, :integer
    add_column :categories, :threads_month, :integer
    add_column :categories, :threads_week, :integer

    remove_column :categories, :posts_year
    remove_column :categories, :posts_month
    remove_column :categories, :posts_week
  end
end
