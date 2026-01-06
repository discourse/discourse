# frozen_string_literal: true

class AddSlugToTags < ActiveRecord::Migration[7.2]
  BATCH_SIZE = 1000

  def up
    add_column :tags, :slug, :string, null: true unless column_exists?(:tags, :slug)

    backfill_slugs
    resolve_conflicts
  end

  def down
    remove_column :tags, :slug
  end

  private

  def backfill_slugs
    # - remove non-alphanumeric except spaces/dashes
    # - lowercase
    # - spaces to dashes
    # - squeeze consecutive dashes
    # - trim leading/trailing dashes
    # - if empty or numeric-only, use <id>-tag
    last_id = 0

    loop do
      result = DB.query(<<~SQL, last_id: last_id, batch_size: BATCH_SIZE)
        WITH batch AS (
          SELECT id FROM tags
          WHERE slug IS NULL AND id > :last_id
          ORDER BY id
          LIMIT :batch_size
        ),
        generated AS (
          SELECT
            tags.id,
            trim(both '-' from
              regexp_replace(
                regexp_replace(
                  regexp_replace(
                    lower(COALESCE(NULLIF(TRIM(tags.name), ''), '')),
                    '''', '', 'g'
                  ),
                  '[^a-z0-9\\s-]', '', 'g'
                ),
                '[\\s-]+', '-', 'g'
              )
            ) AS generated_slug
          FROM tags
          INNER JOIN batch ON batch.id = tags.id
        )
        UPDATE tags
        SET slug = CASE
          WHEN generated.generated_slug = '' THEN tags.id::text || '-tag'
          WHEN generated.generated_slug ~ '^[0-9]+$' THEN tags.id::text || '-tag'
          ELSE generated.generated_slug
        END
        FROM generated
        WHERE tags.id = generated.id
        RETURNING tags.id
      SQL

      break if result.empty?
      last_id = result.max_by(&:id).id
    end
  end

  def resolve_conflicts
    # - for duplicate slugs, append -tag to the newer tag (higher id)
    # - single-level conflict resolution only
    last_id = 0

    loop do
      result = DB.query(<<~SQL, last_id: last_id, batch_size: BATCH_SIZE)
        WITH conflicts AS (
          SELECT t1.id
          FROM tags t1
          WHERE t1.id > :last_id
            AND EXISTS (
              SELECT 1 FROM tags t2
              WHERE lower(t2.slug) = lower(t1.slug)
                AND t2.id < t1.id
            )
          ORDER BY t1.id
          LIMIT :batch_size
        )
        UPDATE tags
        SET slug = tags.slug || '-tag'
        FROM conflicts
        WHERE tags.id = conflicts.id
        RETURNING tags.id
      SQL

      break if result.empty?
      last_id = result.max_by(&:id).id
    end
  end
end
