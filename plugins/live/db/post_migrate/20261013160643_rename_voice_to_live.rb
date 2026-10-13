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

  def up
    RENAMED_TABLES.each do |old_name, new_name|
      rename_table(old_name, new_name) if table_exists?(old_name) && !table_exists?(new_name)
    end

    # rename_table only renames conventionally named indexes and sequences;
    # sweep up the custom-named ones and any readonly triggers/functions left
    # by the column-drop lifecycle.
    DB
      .query_single(
        "SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace " \
          "WHERE n.nspname = 'public' AND c.relkind = 'i' AND c.relname ~ '(^|_)voice_'",
      )
      .each { |name| execute "ALTER INDEX #{name} RENAME TO #{live_name(name)}" }

    DB
      .query_single(
        "SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace " \
          "WHERE n.nspname = 'public' AND c.relkind = 'S' AND c.relname ~ '(^|_)voice_'",
      )
      .each { |name| execute "ALTER SEQUENCE #{name} RENAME TO #{live_name(name)}" }

    # Index-backed constraints were renamed along with their indexes above.
    DB
      .query(
        "SELECT con.conname, c.relname FROM pg_constraint con JOIN pg_class c ON c.oid = con.conrelid " \
          "JOIN pg_namespace n ON n.oid = c.relnamespace " \
          "WHERE n.nspname = 'public' AND con.contype IN ('c', 'f', 'n') AND con.conname ~ '(^|_)voice_'",
      )
      .each do |row|
        execute "ALTER TABLE #{row.relname} RENAME CONSTRAINT #{row.conname} TO #{live_name(row.conname)}"
      end

    DB
      .query(
        "SELECT t.tgname, c.relname FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid " \
          "WHERE NOT t.tgisinternal AND t.tgname ~ '(^|_)voice_'",
      )
      .each do |row|
        execute "ALTER TRIGGER #{row.tgname} ON #{row.relname} RENAME TO #{live_name(row.tgname)}"
      end

    DB
      .query_single(
        "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace " \
          "WHERE n.nspname = 'public' AND p.proname ~ '(^|_)voice_'",
      )
      .each { |function| execute "ALTER FUNCTION #{function}() RENAME TO #{live_name(function)}" }

    execute <<~SQL
      UPDATE site_settings
      SET name = REGEXP_REPLACE(name, '^voice_', 'live_')
      WHERE name LIKE 'voice\\_%'
        AND REGEXP_REPLACE(name, '^voice_', 'live_') NOT IN (SELECT name FROM site_settings)
    SQL

    execute <<~SQL
      UPDATE site_setting_groups
      SET name = REGEXP_REPLACE(name, '^voice_', 'live_')
      WHERE name LIKE 'voice\\_%'
        AND REGEXP_REPLACE(name, '^voice_', 'live_') NOT IN (SELECT name FROM site_setting_groups)
    SQL

    execute <<~SQL
      UPDATE site_setting_localizations
      SET setting_name = REGEXP_REPLACE(setting_name, '^voice_', 'live_')
      WHERE setting_name LIKE 'voice\\_%'
    SQL

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

  def live_name(name)
    name.gsub(/(^|_)voice_/, '\1live_')
  end
end
