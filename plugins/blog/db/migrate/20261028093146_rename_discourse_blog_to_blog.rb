# frozen_string_literal: true

# The plugin was renamed from "discourse-blog" to "blog". The historical
# migrations still create the discourse_blog_* schema; this converts it, along
# with every persisted reference to the old name.
class RenameDiscourseBlogToBlog < ActiveRecord::Migration[8.1]
  RENAMED_TABLES = {
    discourse_blog_publications: :blog_publications,
    discourse_blog_paths: :blog_paths,
    discourse_blog_revisions: :blog_revisions,
    discourse_blog_reviews: :blog_reviews,
    discourse_blog_review_feedback: :blog_review_feedback,
  }

  RENAMED_SETTINGS =
    %w[
      discourse_blog_enabled
      discourse_blog_url
      discourse_blog_category
      discourse_blog_drafts_category
      discourse_blog_title
      discourse_blog_description
      discourse_blog_about
      discourse_blog_posts_per_page
      discourse_blog_contributor_groups
      discourse_blog_editor_groups
      discourse_blog_publisher_groups
    ].to_h { |name| [name, name.delete_prefix("discourse_")] }

  RENAMED_TYPES = {
    "DiscourseBlog::Review" => "Blog::Review",
    "DiscourseBlog::Revision" => "Blog::Revision",
  }

  def up
    Migration::SafeMigrate.disable!

    renamed_tables =
      RENAMED_TABLES.select do |old_name, new_name|
        table_exists?(old_name) && !table_exists?(new_name)
      end
    renamed_tables.each { |old_name, new_name| rename_table(old_name, new_name) }

    RENAMED_TABLES.each do |old_name, new_name|
      rename_table_objects(old_name.to_s, new_name.to_s) if table_exists?(new_name)
    end

    # App servers still running the old code read these until FinishRenameDiscourseBlogToBlog runs.
    renamed_tables.each do |old_name, new_name|
      execute "CREATE VIEW #{old_name} AS SELECT * FROM #{new_name}"
    end

    Migration::SafeMigrate.enable!

    RENAMED_SETTINGS.each do |old_name, new_name|
      DB.exec(<<~SQL, old_name:, new_name:)
        UPDATE site_settings
        SET name = :new_name
        WHERE name = :old_name
          AND NOT EXISTS (SELECT 1 FROM site_settings WHERE name = :new_name)
      SQL

      DB.exec(<<~SQL, old_name:, new_name:)
        UPDATE site_setting_groups
        SET name = :new_name
        WHERE name = :old_name
          AND NOT EXISTS (SELECT 1 FROM site_setting_groups WHERE name = :new_name)
      SQL

      DB.exec(<<~SQL, old_name:, new_name:)
        UPDATE site_setting_localizations
        SET setting_name = :new_name
        WHERE setting_name = :old_name
      SQL
    end

    RENAMED_TYPES.each { |old_type, new_type| DB.exec(<<~SQL, old_type:, new_type:) }
        UPDATE upload_references old
        SET target_type = :new_type
        WHERE old.target_type = :old_type
          AND NOT EXISTS (
            SELECT 1 FROM upload_references
            WHERE upload_id = old.upload_id AND target_type = :new_type AND target_id = old.target_id
          )
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # rename_table only renames conventionally named indexes and sequences, so
  # rename the table's remaining objects that still embed its old name.
  # Index-backed constraints follow their indexes.
  def rename_table_objects(old_name, new_name)
    rename = ->(name) { name.sub(old_name, new_name) }
    table = quote_table_name(new_name)

    DB
      .query_single(<<~SQL, new_name, old_name)
        SELECT i.relname
        FROM pg_index x
        JOIN pg_class i ON i.oid = x.indexrelid
        WHERE x.indrelid = ?::regclass AND strpos(i.relname, ?) > 0
      SQL
      .each do |name|
        execute "ALTER INDEX #{quote_table_name(name)} RENAME TO #{quote_table_name(rename[name])}"
      end

    DB
      .query_single(<<~SQL, new_name, old_name)
        SELECT s.relname
        FROM pg_class s
        JOIN pg_depend d ON d.objid = s.oid AND d.classid = 'pg_class'::regclass
        WHERE s.relkind = 'S' AND d.refobjid = ?::regclass AND d.deptype IN ('a', 'i')
          AND strpos(s.relname, ?) > 0
      SQL
      .each do |name|
        execute "ALTER SEQUENCE #{quote_table_name(name)} RENAME TO #{quote_table_name(rename[name])}"
      end

    DB
      .query_single(<<~SQL, new_name, old_name)
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = ?::regclass AND contype IN ('c', 'f', 'n') AND strpos(conname, ?) > 0
      SQL
      .each do |name|
        execute "ALTER TABLE #{table} RENAME CONSTRAINT #{quote_column_name(name)} TO #{quote_column_name(rename[name])}"
      end
  end
end
