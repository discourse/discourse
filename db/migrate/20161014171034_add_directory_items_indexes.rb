class AddDirectoryItemsIndexes < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index :directory_items, :likes_received, algorithm: :concurrently
    add_index :directory_items, :likes_given, algorithm: :concurrently
    add_index :directory_items, :topics_entered, algorithm: :concurrently
    add_index :directory_items, :topic_count, algorithm: :concurrently
    add_index :directory_items, :post_count, algorithm: :concurrently
    add_index :directory_items, :posts_read, algorithm: :concurrently
    add_index :directory_items, :days_visited, algorithm: :concurrently
  end
end
