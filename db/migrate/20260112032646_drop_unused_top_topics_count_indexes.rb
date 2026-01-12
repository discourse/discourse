# frozen_string_literal: true

class DropUnusedTopTopicsCountIndexes < ActiveRecord::Migration[8.0]
  def up
    remove_index :top_topics, :daily_posts_count
    remove_index :top_topics, :daily_views_count
    remove_index :top_topics, :daily_likes_count
    remove_index :top_topics, :daily_op_likes_count
    remove_index :top_topics, :weekly_posts_count
    remove_index :top_topics, :weekly_views_count
    remove_index :top_topics, :weekly_likes_count
    remove_index :top_topics, :weekly_op_likes_count
    remove_index :top_topics, :monthly_posts_count
    remove_index :top_topics, :monthly_views_count
    remove_index :top_topics, :monthly_likes_count
    remove_index :top_topics, :monthly_op_likes_count
    remove_index :top_topics, :quarterly_posts_count
    remove_index :top_topics, :quarterly_views_count
    remove_index :top_topics, :quarterly_likes_count
    remove_index :top_topics, :quarterly_op_likes_count
    remove_index :top_topics, :yearly_posts_count
    remove_index :top_topics, :yearly_views_count
    remove_index :top_topics, :yearly_likes_count
    remove_index :top_topics, :yearly_op_likes_count
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
