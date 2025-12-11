# frozen_string_literal: true

class AddSlugToTags < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_column :tags, :slug, :string, null: true, if_not_exists: true

    # slugs = lowercase(name).sub(" ", "-"), except
    # - empty name:       <id>-tag
    # - numeric:          <id>-tag
    # - not alphanumeric: <id>-tag
    batch_size = 1000
    last_id = 0

    loop do
      result = execute <<~SQL
        WITH batch AS (
          SELECT id FROM tags
          WHERE slug IS NULL
          AND id > #{last_id}
          ORDER BY id
          LIMIT #{batch_size}
        )
        UPDATE tags
        SET slug = CASE
          WHEN tags.name = '' THEN tags.id::text || '-tag'
          WHEN tags.name ~ '^[0-9]+$' THEN tags.id::text || '-tag'
          WHEN tags.name !~ '^[a-zA-Z0-9\\s\\-]+$' THEN tags.id::text || '-tag'
          ELSE COALESCE(
            NULLIF(
              trim(both '-' from regexp_replace(
                regexp_replace(
                  lower(tags.name),
                  '\\s+', '-', 'g'
                ),
                '-+', '-', 'g'
              )),
              ''
            ),
            tags.id::text || '-tag'
          )
        END
        FROM batch
        WHERE tags.id = batch.id
        RETURNING tags.id
      SQL

      break if result.count == 0
      last_id = result.map { |r| r["id"].to_i }.max
    end

    # we do just a single-level of conflict resolution here
    # e.g. if two tags generated the same slug, we only fix one of them to <id>-tag
    last_id = 0
    loop do
      result = execute <<~SQL
        WITH batch AS (
          SELECT t1.id FROM tags t1
          WHERE t1.id > #{last_id}
          AND EXISTS (
            SELECT 1 FROM tags t2
            WHERE LOWER(t2.slug) = LOWER(t1.slug)
            AND t2.id < t1.id
          )
          AND t1.slug != (t1.id::text || '-tag')
          ORDER BY t1.id
          LIMIT #{batch_size}
        )
        UPDATE tags t1
        SET slug = t1.id::text || '-tag'
        FROM batch
        WHERE t1.id = batch.id
        RETURNING t1.id
      SQL
      break if result.count == 0
      last_id = result.map { |r| r["id"].to_i }.max
    end

    execute "DROP INDEX CONCURRENTLY IF EXISTS index_tags_on_lower_slug"
    # index_exists = DB.query_single("SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'index_tags_on_lower_slug'").any?
    add_index :tags,
              "lower(slug)",
              unique: true,
              name: "index_tags_on_lower_slug",
              algorithm: :concurrently,
              if_not_exists: true

    execute "DROP INDEX CONCURRENTLY IF EXISTS index_tags_on_slug"
    # index_exists = DB.query_single("SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'index_tags_on_slug'").any?
    add_index :tags, :slug, algorithm: :concurrently, if_not_exists: true

    change_column_null :tags, :slug, false
  end

  def down
    remove_index :tags, name: "index_tags_on_lower_slug", if_exists: true
    remove_index :tags, :slug, if_exists: true
    remove_column :tags, :slug
  end
end
