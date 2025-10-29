# frozen_string_literal: true

class PopulateImageQualitySetting < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL)
      WITH src AS (
        SELECT
        COALESCE(
          CAST((
            SELECT value
            FROM site_settings
            WHERE name = 'recompress_original_jpg_quality'
          ) AS INTEGER),
          90
        ) AS recompress_quality
      )
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT
        'image_quality',
        7,
        CASE
          WHEN recompress_quality BETWEEN 0 AND 60 THEN '50'
          WHEN recompress_quality BETWEEN 61 AND 75 THEN '70'
          WHEN recompress_quality BETWEEN 76 AND 99 THEN '90'
          WHEN recompress_quality = 100 THEN '100'
          ELSE '90'
        END,
        NOW(),
        NOW()
      FROM src
      ON CONFLICT (name) DO UPDATE SET value = EXCLUDED.value;
    SQL
  end

  def down
    execute(<<~SQL)
      DELETE FROM site_settings WHERE name = 'image_quality';
    SQL
  end
end
