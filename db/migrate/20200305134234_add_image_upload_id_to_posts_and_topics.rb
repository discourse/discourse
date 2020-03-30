# frozen_string_literal: true

class AddImageUploadIdToPostsAndTopics < ActiveRecord::Migration[6.0]
  def change
    add_reference :posts, :image_upload, foreign_key: { to_table: :uploads, on_delete: :nullify }
    add_reference :topics, :image_upload, foreign_key: { to_table: :uploads, on_delete: :nullify }

    # No need to run this on rollback
    reversible { |c| c.up do
      # Defining regex here to avoid needing to double-escape the \ characters
      regex = '\/(original|optimized)\/\dX[\/\.\w]*\/([a-zA-Z0-9]+)[\.\w]*'

      # Look for an SHA1 in the existing image_url, and match to the uploads table
      execute <<~SQL
        WITH new_post_image_uploads AS (
          SELECT
            posts.id as post_id,
            uploads.id as upload_id
          FROM posts
          LEFT JOIN LATERAL regexp_matches(posts.image_url, '#{regex}') matched_sha1 ON TRUE
          LEFT JOIN uploads on uploads.sha1 = matched_sha1[2]
          WHERE posts.image_url IS NOT NULL
        )
        UPDATE posts SET image_upload_id = new_post_image_uploads.upload_id
        FROM new_post_image_uploads
        WHERE new_post_image_uploads.post_id = posts.id
        AND new_post_image_uploads.upload_id IS NOT NULL
      SQL

      # Update the topic image based on the first post image
      execute <<~SQL
        WITH first_post_images AS (
          SELECT
            posts.topic_id as topic_id,
            posts.image_upload_id as image_upload_id
          FROM posts
          WHERE posts.image_upload_id IS NOT NULL
          AND posts.post_number = 1
        )
        UPDATE topics SET image_upload_id = first_post_images.image_upload_id
        FROM first_post_images
        WHERE first_post_images.topic_id = topics.id
      SQL

      # For posts we couldn't figure out, mark them for background rebake
      execute <<~SQL
        WITH missing_post_images AS (
          SELECT posts.id as post_id
          FROM posts
          WHERE posts.image_upload_id IS NULL
          AND posts.image_url IS NOT NULL
        )
        UPDATE posts SET baked_version = NULL
        FROM missing_post_images
        WHERE missing_post_images.post_id = posts.id
      SQL
    end }

    add_column :theme_modifier_sets, :topic_thumbnail_sizes, :string, array: true
  end
end
