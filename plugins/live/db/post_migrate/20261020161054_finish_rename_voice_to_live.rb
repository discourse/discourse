# frozen_string_literal: true

class FinishRenameVoiceToLive < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      DROP VIEW IF EXISTS
        voice_rooms,
        voice_room_memberships,
        voice_sessions,
        voice_co_presences,
        voice_recordings,
        voice_invites
    SQL

    # Seeds create an empty "Live" grouping when they run before RenameVoiceToLive.
    execute <<~SQL
      UPDATE badge_groupings live
      SET position = voice.position,
          description = COALESCE(live.description, voice.description)
      FROM badge_groupings voice
      WHERE live.name = 'Live' AND voice.name = 'Voice'
    SQL

    execute <<~SQL
      UPDATE badges
      SET badge_grouping_id = live.id
      FROM badge_groupings voice, badge_groupings live
      WHERE badges.badge_grouping_id = voice.id
        AND voice.name = 'Voice'
        AND live.name = 'Live'
    SQL

    execute <<~SQL
      DELETE FROM badge_groupings
      WHERE name = 'Voice'
        AND EXISTS (SELECT 1 FROM badge_groupings WHERE name = 'Live')
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
