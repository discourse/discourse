# frozen_string_literal: true
class BackfillBlogPublicationLiveArticles < ActiveRecord::Migration[8.1]
  def up
    # Nobody can edit a published discussion post, so it carries the approved text, and
    # unlike the revision snapshot it already has any earlier hostname or upload remap.
    execute <<~SQL
      WITH live AS (
        SELECT publications.id,
               COALESCE(posts.cooked, revisions.data->>'cooked') AS cooked,
               CASE
                 WHEN posts.id IS NULL THEN revisions.data->>'image_url'
                 WHEN uploads.id IS NULL OR uploads.secure THEN ''
                 ELSE uploads.url
               END AS image_url
          FROM blog_publications publications
          JOIN blog_revisions revisions ON revisions.id = publications.published_revision_id
          LEFT JOIN posts
            ON posts.topic_id = publications.discussion_topic_id
           AND posts.post_number = 1
           AND posts.deleted_at IS NULL
          LEFT JOIN uploads ON uploads.id = posts.image_upload_id
         WHERE publications.cooked IS NULL
      )
      UPDATE blog_publications
         SET cooked = live.cooked,
             image_url = live.image_url
        FROM live
       WHERE blog_publications.id = live.id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
