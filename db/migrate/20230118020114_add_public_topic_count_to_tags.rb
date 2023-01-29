# frozen_string_literal: true

class AddPublicTopicCountToTags < ActiveRecord::Migration[7.0]
  def up
    add_column :tags, :public_topic_count, :integer, default: 0, null: false

    execute <<~SQL
    UPDATE tags t
    SET public_topic_count = x.topic_count
    FROM (
      SELECT
        COUNT(topics.id) AS topic_count,
        tags.id AS tag_id
      FROM tags
      INNER JOIN topic_tags ON tags.id = topic_tags.tag_id
      INNER JOIN topics ON topics.id = topic_tags.topic_id AND topics.deleted_at IS NULL AND topics.archetype != 'private_message'
      INNER JOIN categories ON categories.id = topics.category_id AND NOT categories.read_restricted
      GROUP BY tags.id
    ) x
    WHERE x.tag_id = t.id
    AND x.topic_count <> t.public_topic_count;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
