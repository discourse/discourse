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

    # The voice code keeps writing these until its app servers restart.
    execute <<~SQL
      UPDATE reviewables voice
      SET type = 'ReviewableLiveUser',
          type_source = 'live',
          target_type = CASE
            WHEN target_type = 'Voice::Session' THEN 'Live::Session'
            ELSE target_type
          END
      WHERE voice.type = 'ReviewableVoiceUser'
        AND NOT EXISTS (
          SELECT 1 FROM reviewables
          WHERE type = 'ReviewableLiveUser' AND target_id = voice.target_id
        )
    SQL

    execute <<~SQL if table_exists?(:chat_thread_custom_fields)
        UPDATE chat_thread_custom_fields voice
        SET name = 'live_room_id'
        WHERE voice.name = 'voice_room_id'
          AND NOT EXISTS (
            SELECT 1 FROM chat_thread_custom_fields
            WHERE name = 'live_room_id' AND thread_id = voice.thread_id
          )
      SQL

    execute <<~SQL
      UPDATE plugin_store_rows voice
      SET plugin_name = 'live'
      WHERE voice.plugin_name = 'voice'
        AND NOT EXISTS (
          SELECT 1 FROM plugin_store_rows
          WHERE plugin_name = 'live' AND key = voice.key
        )
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
