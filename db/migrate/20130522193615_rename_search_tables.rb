# frozen_string_literal: true

class RenameSearchTables < ActiveRecord::Migration[4.2]
  def up
    rename_table :users_search, :user_search_data
    rename_column :user_search_data, :id, :user_id
    rename_table :categories_search, :category_search_data
    rename_column :category_search_data, :id, :category_id
    rename_table :posts_search, :post_search_data
    rename_column :post_search_data, :id, :post_id
  end

  def down
    rename_table :user_search_data, :users_search
    rename_column :users_search, :user_id, :id
    rename_table :category_search_data, :categories_search
    rename_column :categories_search, :category_id, :id
    rename_table :post_search_data, :posts_search
    rename_column :posts_search, :post_id, :id
  end
end
