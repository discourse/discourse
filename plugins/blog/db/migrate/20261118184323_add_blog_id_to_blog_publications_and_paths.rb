# frozen_string_literal: true
class AddBlogIdToBlogPublicationsAndPaths < ActiveRecord::Migration[8.1]
  def up
    add_column :blog_publications, :blog_id, :bigint
    add_column :blog_paths, :blog_id, :bigint

    backfill_blog_ids

    add_index :blog_publications,
              %i[blog_id published published_at],
              name: "idx_blog_publications_on_blog_id_published_at"
    add_index :blog_paths, %i[blog_id path], unique: true
  end

  def down
    remove_column :blog_paths, :blog_id
    remove_column :blog_publications, :blog_id
  end

  private

  def backfill_blog_ids
    return if DB.query_single("SELECT 1 FROM blog_publications LIMIT 1").empty?

    # Seeds run after migrations, so a site upgrading past the blogs table in one
    # deploy has no default blog yet. The fixture fills it in from the settings.
    blog_id =
      DB.query_single("SELECT id FROM blog_instances WHERE is_default").first ||
        DB.query_single(<<~SQL).first
          INSERT INTO blog_instances (name, slug, is_default, created_at, updated_at)
          VALUES ('', 'blog', TRUE, NOW(), NOW())
          RETURNING id
        SQL

    DB.exec("UPDATE blog_publications SET blog_id = :blog_id WHERE blog_id IS NULL", blog_id:)
    execute <<~SQL
      UPDATE blog_paths
      SET blog_id = blog_publications.blog_id
      FROM blog_publications
      WHERE blog_publications.id = blog_paths.publication_id AND blog_paths.blog_id IS NULL
    SQL
  end
end
