class AddBadgePostsAndTopicsView < ActiveRecord::Migration
  def up
    add_column :categories, :allow_badges, :boolean, default: true, null: false

    execute "CREATE VIEW badge_posts AS
    SELECT p.*
    FROM posts p
    JOIN topics t ON t.id = p.topic_id
    JOIN categories c ON c.id = t.category_id
    WHERE c.allow_badges AND
          p.deleted_at IS NULL AND
          t.deleted_at IS NULL AND
          t.visible"
  end

  def down
    execute "DROP VIEW badge_posts"
    remove_column :categories, :allow_badges
  end
end
