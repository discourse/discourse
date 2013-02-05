class AddColumnSummariesToPostsAndTopics < ActiveRecord::Migration
  def change
    add_column :posts, :spam_count, :integer, default: 0, null: false
    add_column :topics, :spam_count, :integer, default: 0, null: false
    add_column :posts, :illegal_count, :integer, default: 0, null: false
    add_column :topics, :illegal_count, :integer, default: 0, null: false
    add_column :posts, :inappropriate_count, :integer, default: 0, null: false
    add_column :topics, :inappropriate_count, :integer, default: 0, null: false
    remove_column :posts, :offensive_count
    remove_column :topics, :offensive_count
  end
end
