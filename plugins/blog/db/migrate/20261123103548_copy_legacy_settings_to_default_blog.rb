# frozen_string_literal: true

# The default blog's row replaced these site settings. A site that set up its blog
# before the row existed, and has not deployed since, still has its values there.
class CopyLegacySettingsToDefaultBlog < ActiveRecord::Migration[8.1]
  SETTINGS = %w[
    blog_title
    blog_description
    blog_about
    blog_url
    blog_category
    blog_path_format
    blog_posts_per_page
  ]

  def up
    return if DB.query_single("SELECT 1 FROM blog_instances WHERE is_default AND name <> ''").any?

    settings =
      DB
        .query_array(
          "SELECT name, value FROM site_settings WHERE name IN (:names)",
          names: SETTINGS,
        )
        .to_h
        .compact_blank
    placeholder = DB.query_single("SELECT 1 FROM blog_instances WHERE is_default").any?
    # A site that never configured a blog gets its row from the fixture.
    return if settings.empty? && !placeholder

    execute <<~SQL if !placeholder
      INSERT INTO blog_instances (name, slug, is_default, created_at, updated_at)
      VALUES ('', 'blog', TRUE, NOW(), NOW())
    SQL

    DB.exec(
      <<~SQL,
        UPDATE blog_instances
        SET name = :name,
            description = :description,
            about = :about,
            url = :url,
            category_id = :category_id,
            path_format = :path_format,
            posts_per_page = :posts_per_page,
            active_theme = COALESCE(
              active_theme,
              (
                SELECT value::jsonb
                FROM plugin_store_rows
                WHERE plugin_name = 'discourse-blog-themes' AND key = 'active' AND type_name = 'JSON'
                LIMIT 1
              )
            )
        WHERE is_default
      SQL
      name: settings["blog_title"] || "The blog",
      description: settings["blog_description"] || "Ideas, stories, and conversations.",
      about: settings["blog_about"].to_s,
      url: settings["blog_url"],
      category_id: settings["blog_category"]&.to_i,
      path_format: settings["blog_path_format"] || "/{slug}",
      posts_per_page: settings["blog_posts_per_page"]&.to_i || 10,
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
