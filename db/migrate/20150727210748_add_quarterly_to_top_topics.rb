class AddQuarterlyToTopTopics < ActiveRecord::Migration[4.2]
  def change
    add_column :top_topics, :quarterly_posts_count,    :integer, default: 0, null: false
    add_column :top_topics, :quarterly_views_count,    :integer, default: 0, null: false
    add_column :top_topics, :quarterly_likes_count,    :integer, default: 0, null: false
    add_column :top_topics, :quarterly_score,          :float,   default: 0.0
    add_column :top_topics, :quarterly_op_likes_count, :integer, default: 0, null: false

    add_index :top_topics, [:quarterly_posts_count]
    add_index :top_topics, [:quarterly_views_count]
    add_index :top_topics, [:quarterly_likes_count]
    add_index :top_topics, [:quarterly_op_likes_count]
  end
end
