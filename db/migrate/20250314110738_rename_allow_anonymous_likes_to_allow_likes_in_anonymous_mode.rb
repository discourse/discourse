# frozen_string_literal: true

class RenameAllowAnonymousLikesToAllowLikesInAnonymousMode < ActiveRecord::Migration[7.2]
  def up
    execute(<<~SQL)
      WITH renamed AS (
        DELETE FROM site_settings
        WHERE name = 'allow_anonymous_likes'
        RETURNING 'allow_likes_in_anonymous_mode' AS name, data_type, value, created_at, updated_at
      )
      INSERT INTO site_settings
      (name, data_type, value, created_at, updated_at)
      SELECT * FROM renamed
    SQL
  end

  def down
    execute(<<~SQL)
      WITH renamed AS (
        DELETE FROM site_settings
        WHERE name = 'allow_likes_in_anonymous_mode'
        RETURNING 'allow_anonymous_likes' AS name, data_type, value, created_at, updated_at
      )
      INSERT INTO site_settings
      (name, data_type, value, created_at, updated_at)
      SELECT * FROM renamed
    SQL
  end
end
