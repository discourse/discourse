# frozen_string_literal: true
class BackfillBlogPublicationLiveArticles < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE blog_publications
         SET cooked = revisions.data->>'cooked',
             image_url = revisions.data->>'image_url'
        FROM blog_revisions revisions
       WHERE revisions.id = blog_publications.published_revision_id
         AND blog_publications.cooked IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
