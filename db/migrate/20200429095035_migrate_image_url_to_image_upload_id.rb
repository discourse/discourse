# frozen_string_literal: true

class MigrateImageUrlToImageUploadId < ActiveRecord::Migration[6.0]
  disable_ddl_transaction! # Avoid holding update locks on posts for the whole migration

  BATCH_SIZE = 1000

  def up
    # Defining regex here to avoid needing to double-escape the \ characters
    regex = '\/(original|optimized)\/\dX[\/\.\w]*\/([a-zA-Z0-9]+)[\.\w]*'

    # Can't use a real temporary table because we're running outside a transaction
    # and the connection could change between statements
    drop_temporary_table! # First check it doesn't already exist
    execute <<~SQL
      CREATE TABLE tmp_post_image_uploads(
        post_id int primary key,
        upload_id int
      )
    SQL

    # Look for an SHA1 in the existing image_url, and match to the uploads table
    execute <<~SQL
      INSERT INTO tmp_post_image_uploads(post_id, upload_id)
      SELECT
        posts.id as post_id,
        uploads.id as upload_id
      FROM posts
      LEFT JOIN LATERAL regexp_matches(posts.image_url, '#{regex}') matched_sha1 ON TRUE
      LEFT JOIN uploads on uploads.sha1 = matched_sha1[2]
      WHERE posts.image_url IS NOT NULL
      AND uploads.id IS NOT NULL
      ORDER BY posts.id ASC
    SQL

    # Update the posts table to match the temp table data
    last_update_id = -1
    begin
      result = DB.query <<~SQL
        WITH to_update AS (
          SELECT post_id, upload_id
          FROM tmp_post_image_uploads
          JOIN posts ON posts.id = post_id
          WHERE posts.id > #{last_update_id}
          ORDER BY post_id ASC
          LIMIT #{BATCH_SIZE}
        )
        UPDATE posts SET image_upload_id = to_update.upload_id
        FROM to_update
        WHERE to_update.post_id = posts.id
        RETURNING posts.id
      SQL
      last_update_id = result.last&.id
    end while last_update_id

    # Update the topic image based on the first post image
    last_update_id = -1
    begin
      result = DB.query <<~SQL
        WITH to_update AS (
          SELECT topic_id, posts.image_upload_id as upload_id
          FROM topics
          JOIN posts ON post_number = 1 AND posts.topic_id = topics.id
          WHERE posts.image_upload_id IS NOT NULL
          AND topics.id > #{last_update_id}
          ORDER BY topics.id ASC
          LIMIT #{BATCH_SIZE}
        )
        UPDATE topics SET image_upload_id = to_update.upload_id
        FROM to_update
        WHERE topics.id = to_update.topic_id
        RETURNING topics.id
      SQL
      last_update_id = result.last&.id
    end while last_update_id

    # For posts we couldn't figure out, mark them for background rebake
    last_update_id = -1
    begin
      updated_count = DB.query <<~SQL
        WITH to_update AS (
          SELECT id as post_id
          FROM posts
          WHERE posts.image_url IS NOT NULL
          AND posts.image_upload_id IS NULL
          AND posts.id > #{last_update_id}
          ORDER BY posts.id ASC
          LIMIT #{BATCH_SIZE}
        )
        UPDATE posts SET baked_version = NULL
        FROM to_update
        WHERE posts.id = to_update.post_id
        RETURNING posts.id
      SQL
      last_update_id = result.last&.id
    end while last_update_id
  ensure
    drop_temporary_table!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def drop_temporary_table!
    Migration::SafeMigrate.disable!
    execute <<~SQL
      DROP TABLE IF EXISTS tmp_post_image_uploads
    SQL
    Migration::SafeMigrate.enable!
  end
end
