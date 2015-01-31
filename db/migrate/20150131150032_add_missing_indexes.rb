class AddMissingIndexes < ActiveRecord::Migration
  def change
    add_index :user_stats, :user_id
    add_index :users, :id, unique: true
    execute "DROP INDEX IF EXISTS idx_posts_created_at_topic_id"
    add_index :posts, [:created_at, :topic_id, :deleted_at]
  end
end
