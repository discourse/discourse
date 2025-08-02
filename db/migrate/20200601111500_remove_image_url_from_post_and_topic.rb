# frozen_string_literal: true

class RemoveImageUrlFromPostAndTopic < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
      ALTER TABLE topics DROP COLUMN IF EXISTS image_url
    SQL

    ActiveRecord::Base.transaction do
      execute "DROP VIEW badge_posts"

      execute <<~SQL
        ALTER TABLE posts DROP COLUMN IF EXISTS image_url
      SQL

      # we must recreate this view every time we amend posts
      # p.* is auto expanded and persisted into the view definition
      # at create time
      execute <<~SQL
        CREATE VIEW badge_posts AS
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
    end
  end

  def down
    # do nothing re-runnable
  end
end
