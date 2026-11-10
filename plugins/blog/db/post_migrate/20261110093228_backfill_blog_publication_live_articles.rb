# frozen_string_literal: true
class BackfillBlogPublicationLiveArticles < ActiveRecord::Migration[8.1]
  def up
    # A discussion post that still carries the published text already has any later
    # rebakes and remaps, so it is a better source than the revision snapshot.
    execute <<~SQL
      WITH live AS (
        SELECT publications.id,
               COALESCE(posts.cooked, revisions.data->>'cooked') AS cooked,
               CASE
                 WHEN posts.id IS NULL THEN revisions.data->>'image_url'
                 WHEN uploads.id IS NULL OR uploads.secure THEN ''
                 ELSE uploads.url
               END AS image_url,
               posts.version AS discussion_post_version
          FROM blog_publications publications
          JOIN blog_revisions revisions ON revisions.id = publications.published_revision_id
          LEFT JOIN posts
            ON posts.topic_id = publications.discussion_topic_id
           AND posts.post_number = 1
           AND posts.deleted_at IS NULL
           AND posts.raw = revisions.data->>'raw'
          LEFT JOIN uploads ON uploads.id = posts.image_upload_id
         WHERE publications.cooked IS NULL
      )
      UPDATE blog_publications
         SET cooked = live.cooked,
             image_url = live.image_url,
             discussion_post_version = live.discussion_post_version
        FROM live
       WHERE blog_publications.id = live.id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
