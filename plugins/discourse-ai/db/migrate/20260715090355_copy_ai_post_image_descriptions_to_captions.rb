# frozen_string_literal: true

class CopyAiPostImageDescriptionsToCaptions < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS ai_post_image_captions (
        id bigserial PRIMARY KEY,
        post_id integer NOT NULL,
        upload_id integer NOT NULL,
        base62_sha1 varchar(27) NOT NULL,
        locale varchar(20) NOT NULL,
        description text,
        attempts integer DEFAULT 0 NOT NULL,
        last_attempted_at timestamp(6) without time zone,
        last_error text,
        created_at timestamp(6) without time zone NOT NULL,
        updated_at timestamp(6) without time zone NOT NULL
      )
    SQL

    execute <<~SQL
      CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_post_image_captions_lookup
      ON ai_post_image_captions (post_id, locale, base62_sha1)
    SQL

    execute <<~SQL
      CREATE INDEX IF NOT EXISTS idx_ai_post_image_captions_reuse
      ON ai_post_image_captions (base62_sha1, locale)
    SQL

    return if !table_exists?(:ai_post_image_descriptions)

    execute <<~SQL
      INSERT INTO ai_post_image_captions (
        post_id,
        upload_id,
        base62_sha1,
        locale,
        description,
        attempts,
        last_attempted_at,
        last_error,
        created_at,
        updated_at
      )
      SELECT
        post_id,
        upload_id,
        base62_sha1,
        locale,
        description,
        attempts,
        last_attempted_at,
        last_error,
        created_at,
        updated_at
      FROM ai_post_image_descriptions
      ON CONFLICT (post_id, locale, base62_sha1) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
