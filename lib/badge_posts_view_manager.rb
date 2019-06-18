# frozen_string_literal: true

class BadgePostsViewManager
  VIEW_NAME = "badge_posts".freeze

  def self.create!
    sql = <<~SQL
    CREATE VIEW #{VIEW_NAME} AS
    SELECT p.*
    FROM posts p
    JOIN topics t ON t.id = p.topic_id
    JOIN categories c ON c.id = t.category_id
    WHERE c.allow_badges AND
          p.deleted_at IS NULL AND
          t.deleted_at IS NULL AND
          NOT c.read_restricted AND
          t.visible AND
          p.post_type IN (1,2,3)
    SQL

    DB.exec(sql)
    raise "Failed to create '#{VIEW_NAME}' view" unless badge_posts_view_exists?
  end

  def self.drop!
    DB.exec("DROP VIEW #{VIEW_NAME}")
    raise "Failed to drop '#{VIEW_NAME}' view" if badge_posts_view_exists?
  end

  def self.badge_posts_view_exists?
    sql = <<~SQL
    SELECT 1
    FROM pg_catalog.pg_views
    WHERE schemaname
    IN ('public')
    AND viewname = '#{VIEW_NAME}';
    SQL

    DB.exec(sql) == 1
  end
end
