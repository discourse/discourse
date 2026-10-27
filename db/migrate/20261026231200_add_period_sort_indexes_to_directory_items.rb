# frozen_string_literal: true
class AddPeriodSortIndexesToDirectoryItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  COLUMNS = %i[
    likes_received
    likes_given
    topics_entered
    topic_count
    post_count
    posts_read
    days_visited
  ]

  def up
    COLUMNS.each do |column|
      remove_index :directory_items,
                   [:period_type, column, :id],
                   algorithm: :concurrently,
                   if_exists: true
      add_index :directory_items, [:period_type, column, :id], algorithm: :concurrently
    end
  end

  def down
    COLUMNS.each do |column|
      remove_index :directory_items,
                   [:period_type, column, :id],
                   algorithm: :concurrently,
                   if_exists: true
    end
  end
end
