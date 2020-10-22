# frozen_string_literal: true

class CorrectPostsSchema < ActiveRecord::Migration[6.0]
  # In the past, rails changed the default behavior for varchar columns
  # This only affects older discourse installations
  # This migration removes the character limits from posts columns, so that they match modern behavior
  #
  # To modify the posts table schema we need to recreate the badge_posts view
  # This should be done in a transaction
  def up
    result = DB.query <<~SQL
      SELECT character_maximum_length 
      FROM information_schema.columns 
      WHERE table_schema='public'
      AND table_name = 'posts' 
      AND column_name IN ('action_code', 'edit_reason')
    SQL

    # No need to continue if the schema is already correct
    return if result.all? { |r| r.character_maximum_length.nil? }

    execute "DROP VIEW badge_posts"

    execute "ALTER TABLE posts ALTER COLUMN action_code TYPE varchar"
    execute "ALTER TABLE posts ALTER COLUMN edit_reason TYPE varchar"

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

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
