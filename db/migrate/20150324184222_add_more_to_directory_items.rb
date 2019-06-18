# frozen_string_literal: true

class AddMoreToDirectoryItems < ActiveRecord::Migration[4.2]
  def change
    add_column :directory_items, :days_visited, :integer, null: false, default: 0
    add_column :directory_items, :posts_read, :integer, null: false, default: 0
  end
end
