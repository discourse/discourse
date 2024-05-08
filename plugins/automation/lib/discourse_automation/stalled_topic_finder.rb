# frozen_string_literal: true

class DiscourseAutomation::StalledTopicFinder
  def self.call(stalled_date, tags: nil, categories: nil)
    sql = <<~SQL
      SELECT t.id
      FROM topics t
    SQL

    sql += <<~SQL if tags
        JOIN topic_tags ON topic_tags.topic_id = t.id
        JOIN tags
          ON tags.name IN (:tags)
          AND tags.id = topic_tags.tag_id
      SQL

    sql += <<~SQL
      WHERE t.deleted_at IS NULL
      AND t.posts_count > 0
      AND t.archetype != 'private_message'
      AND NOT t.closed
      AND NOT t.archived
      AND NOT EXISTS (
        SELECT p.id
        FROM posts p
        WHERE t.id = p.topic_id
          AND p.deleted_at IS NULL
          AND t.user_id = p.user_id
          AND p.created_at > :stalled_date
        LIMIT 1
      )
    SQL

    sql += <<~SQL if categories
        AND t.category_id IN (:categories)
      SQL

    sql += <<~SQL
      LIMIT 250
    SQL

    DB.query(sql, categories: categories, tags: tags, stalled_date: stalled_date)
  end
end
