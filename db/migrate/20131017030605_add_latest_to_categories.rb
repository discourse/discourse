class AddLatestToCategories < ActiveRecord::Migration
  def up
    add_column :categories, :latest_post_id, :integer
    add_column :categories, :latest_topic_id, :integer

    execute <<SQL
    UPDATE categories c
    SET latest_post_id = x.post_id
    FROM (select category_id, max(p.id) post_id FROM posts p
          JOIN topics t on t.id = p.topic_id
          WHERE p.deleted_at IS NULL AND NOT p.hidden AND t.visible
          GROUP BY category_id
         ) x
    WHERE x.category_id = c.id
SQL

    execute <<SQL
    UPDATE categories c
    SET latest_topic_id = x.topic_id
    FROM (select category_id, max(t.id) topic_id
          FROM topics t
          WHERE t.deleted_at IS NULL AND t.visible
          GROUP BY category_id
         ) x
    WHERE x.category_id = c.id
SQL
  end

  def down
    remove_column :categories, :latest_post_id
    remove_column :categories, :latest_topic_id
  end
end
