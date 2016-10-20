class AddDirectoryItemsIndexes < ActiveRecord::Migration
  def change
    add_index :directory_items, :likes_received
    add_index :directory_items, :likes_given
    add_index :directory_items, :topics_entered
    add_index :directory_items, :topic_count
    add_index :directory_items, :post_count
    add_index :directory_items, :posts_read
    add_index :directory_items, :days_visited
  end
end
