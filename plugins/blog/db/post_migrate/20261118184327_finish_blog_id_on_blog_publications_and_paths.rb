# frozen_string_literal: true
class FinishBlogIdOnBlogPublicationsAndPaths < ActiveRecord::Migration[8.1]
  def up
    # The previous code kept writing rows without a blog until it stopped.
    blog_id = DB.query_single("SELECT id FROM blog_instances WHERE is_default").first
    if blog_id
      DB.exec("UPDATE blog_publications SET blog_id = :blog_id WHERE blog_id IS NULL", blog_id:)
      execute <<~SQL
        UPDATE blog_paths
        SET blog_id = blog_publications.blog_id
        FROM blog_publications
        WHERE blog_publications.id = blog_paths.publication_id AND blog_paths.blog_id IS NULL
      SQL
    end

    change_column_null :blog_publications, :blog_id, false
    change_column_null :blog_paths, :blog_id, false

    remove_index :blog_publications, %i[published published_at], if_exists: true
    remove_index :blog_paths, :path, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
