# frozen_string_literal: true

class RestoreVoiceBadgePreferences < ActiveRecord::Migration[8.0]
  CHANGE_BADGE_ACTION = 58

  def up
    execute <<~SQL
      WITH badge_preferences AS (
        SELECT DISTINCT ON (split_part(details, chr(10), 1))
          split_part(details, chr(10), 1) AS badge_id,
          substring(details FROM '(?n)^enabled: (true|false)$') AS enabled
        FROM user_histories
        WHERE action = #{CHANGE_BADGE_ACTION}
          AND details ~ '(?n)^enabled: (true|false)$'
        ORDER BY split_part(details, chr(10), 1), id DESC
      )
      UPDATE badges SET enabled = true, updated_at = CURRENT_TIMESTAMP
      WHERE NOT enabled
        AND (
          plugin_name = 'voice'
          OR (
            plugin_name IS NULL AND system
            AND badge_grouping_id IN (SELECT id FROM badge_groupings WHERE name = 'Voice')
          )
        )
        AND EXISTS (
          SELECT 1 FROM site_settings
          WHERE name = 'voice_badges_enabled' AND value = 'f'
        )
        AND NOT EXISTS (
          SELECT 1 FROM badge_preferences
          WHERE badge_id = 'id: ' || badges.id AND enabled = 'false'
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
