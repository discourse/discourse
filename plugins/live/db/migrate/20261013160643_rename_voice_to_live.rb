# frozen_string_literal: true

# The plugin was renamed from "voice" to "live". The historical migrations
# still create the voice_* schema; this converts it, along with every
# persisted reference to the old name.
class RenameVoiceToLive < ActiveRecord::Migration[8.0]
  RENAMED_TABLES = {
    voice_rooms: :live_rooms,
    voice_room_memberships: :live_room_memberships,
    voice_sessions: :live_sessions,
    voice_co_presences: :live_co_presences,
    voice_recordings: :live_recordings,
    voice_invites: :live_invites,
  }

  RENAMED_SETTINGS =
    %w[
      voice_enabled
      voice_verbose_logging
      voice_allowed_groups
      voice_create_room_allowed_groups
      voice_direct_calls_allowed_groups
      voice_max_rooms_per_user
      voice_max_invites_per_day
      voice_ephemeral_room_ttl_minutes
      voice_participant_ttl_seconds
      voice_max_room_participants
      voice_stun_servers
      voice_turn_servers
      voice_turn_username
      voice_turn_credential
      voice_turn_secret
      voice_turn_secret_servers
      voice_livekit_url
      voice_livekit_api_key
      voice_livekit_api_secret
      voice_livekit_room_policy
      voice_livekit_room_prefix
      voice_livekit_mesh_fallback
      voice_livekit_agent_enabled
      voice_livekit_agent_invite_allowed_groups
      voice_livekit_recording_enabled
      voice_livekit_recording_filepath
      voice_livekit_recording_s3_region
      voice_livekit_recording_s3_access_key_id
      voice_livekit_recording_s3_secret_access_key
      voice_livekit_recording_s3_endpoint
      voice_livekit_recording_s3_bucket
      voice_video_allowed_groups
      voice_screen_share_allowed_groups
      voice_video_max_publishers
      voice_video_background_blur_enabled
      voice_subtitles_enabled
      voice_stt_model_base_url
      voice_max_voice_quality
      voice_max_camera_quality
      voice_max_screen_share_quality
      voice_idle_threshold_minutes
      voice_afk_auto_mute_threshold_minutes
      voice_afk_disconnect_threshold_minutes
      voice_auto_status_enabled
      voice_mesh_privacy_warning_enabled
      voice_badges_enabled
      voice_analytics_enabled
      voice_session_retention_days
      voice_chat_enabled
    ].to_h { |name| [name, name.sub(/\Avoice_/, "live_")] }

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

    # App servers still running the voice code read these until FinishRenameVoiceToLive runs.
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

    # Without this the upcoming change looks brand new and notifies admins
    # again. Once-off events may already exist under the new name if the new
    # code booted first, so conflicts are dropped.
    execute <<~SQL
      INSERT INTO upcoming_change_events
        (event_type, upcoming_change_name, event_data, acting_user_id, created_at, updated_at)
      SELECT event_type, 'live_enabled', event_data, acting_user_id, created_at, updated_at
      FROM upcoming_change_events
      WHERE upcoming_change_name = 'voice_enabled'
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL
      DELETE FROM upcoming_change_events
      WHERE upcoming_change_name = 'voice_enabled'
    SQL

    execute <<~SQL
      UPDATE reviewables
      SET type = 'ReviewableLiveUser',
          type_source = 'live',
          target_type = CASE
            WHEN target_type = 'Voice::Session' THEN 'Live::Session'
            ELSE target_type
          END
      WHERE type = 'ReviewableVoiceUser'
    SQL

    execute <<~SQL if table_exists?(:chat_thread_custom_fields)
        UPDATE chat_thread_custom_fields
        SET name = 'live_room_id'
        WHERE name = 'voice_room_id'
      SQL

    execute <<~SQL
      UPDATE plugin_store_rows
      SET plugin_name = 'live'
      WHERE plugin_name = 'voice'
    SQL

    execute <<~SQL
      UPDATE badge_groupings
      SET name = 'Live'
      WHERE name = 'Voice'
        AND NOT EXISTS (SELECT 1 FROM badge_groupings WHERE name = 'Live')
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

    DB
      .query_single(<<~SQL, new_name, old_name)
        SELECT tgname
        FROM pg_trigger
        WHERE tgrelid = ?::regclass AND NOT tgisinternal AND strpos(tgname, ?) > 0
      SQL
      .each do |name|
        execute "ALTER TRIGGER #{quote_column_name(name)} ON #{table} RENAME TO #{quote_column_name(rename[name])}"
      end

    # Functions called by the table's triggers, e.g. readonly-column guards.
    DB
      .query(<<~SQL, new_name, old_name)
        SELECT DISTINCT p.oid::regprocedure::text AS signature, p.proname
        FROM pg_trigger t
        JOIN pg_proc p ON p.oid = t.tgfoid
        WHERE t.tgrelid = ?::regclass AND NOT t.tgisinternal AND strpos(p.proname, ?) > 0
      SQL
      .each do |row|
        execute "ALTER FUNCTION #{row.signature} RENAME TO #{quote_column_name(rename[row.proname])}"
      end
  end
end
