# frozen_string_literal: true

class EnableVoiceBadgesByDefault < ActiveRecord::Migration[8.0]
  # The setting default flipped to true. Sites that never touched it were
  # implicitly off and their seeded badges are disabled; the setting-changed
  # hook that normally flips them never fires for a default change.
  def up
    execute <<~SQL
      UPDATE badges
      SET enabled = true
      FROM badge_groupings
      WHERE badges.badge_grouping_id = badge_groupings.id
        AND badge_groupings.name = 'Voice'
        AND NOT EXISTS (
          SELECT 1 FROM site_settings
          WHERE name = 'voice_badges_enabled' AND value = 'f'
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
