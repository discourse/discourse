# frozen_string_literal: true
class ConvertAiTranslationBackfillMaxAgeToStartDate < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      WITH previous_settings AS (
        SELECT
          (
            SELECT value
            FROM site_settings
            WHERE name = 'discourse_ai_enabled'
          ) AS discourse_ai_enabled,
          (
            SELECT value
            FROM site_settings
            WHERE name = 'ai_translation_enabled'
          ) AS ai_translation_enabled,
          (
            SELECT value::integer
            FROM site_settings
            WHERE name = 'ai_translation_backfill_hourly_rate'
          ) AS hourly_rate,
          COALESCE(
            (
              SELECT value::integer
              FROM site_settings
              WHERE name = 'ai_translation_backfill_max_age_days'
            ),
            5
          ) AS max_age_days
      )
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      SELECT
        'ai_translation_backfill_start_date',
        33,
        (
          (CURRENT_TIMESTAMP AT TIME ZONE 'UTC') -
          max_age_days * INTERVAL '1 day'
        )::date::text,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM previous_settings
      WHERE discourse_ai_enabled = 't'
        AND ai_translation_enabled = 't'
        AND (hourly_rate IS NULL OR hourly_rate > 0)
        AND max_age_days > 0
        AND NOT EXISTS (
          SELECT 1
          FROM site_settings
          WHERE name = 'ai_translation_backfill_start_date'
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
