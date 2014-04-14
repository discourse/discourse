class AddCreatedAtIndexToPosts < ActiveRecord::Migration
  def up
    execute "CREATE INDEX idx_posts_created_at_topic_id ON posts(created_at, topic_id) WHERE deleted_at IS NULL"
    add_column :categories, :topics_day, :integer, default: 0
    add_column :categories, :posts_day,  :integer, default: 0
    execute "DROP INDEX index_topics_on_deleted_at_and_visible_and_archetype_and_id"
    add_index :topics, [:deleted_at, :visible, :archetype, :category_id, :id], name: "idx_topics_front_page"
  end

  def down
    execute "DROP INDEX idx_topics_front_page"
    add_index :topics, [:deleted_at, :visible, :archetype, :id]
    remove_column :categories, :posts_day
    remove_column :categories, :topics_day
    execute "DROP INDEX idx_posts_created_at_topic_id"
  end
end
