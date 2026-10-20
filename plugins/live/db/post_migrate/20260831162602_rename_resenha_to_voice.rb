# frozen_string_literal: true

# The plugin was renamed from "resenha" to "voice". Fresh installs create the
# voice_* schema directly (the historical migrations were rewritten); this
# migration converts sites that migrated under the old name.
class RenameResenhaToVoice < ActiveRecord::Migration[8.0]
  RENAMED_TABLES = {
    resenha_rooms: :voice_rooms,
    resenha_room_memberships: :voice_room_memberships,
    resenha_sessions: :voice_sessions,
    resenha_co_presences: :voice_co_presences,
    resenha_recordings: :voice_recordings,
    resenha_invites: :voice_invites,
  }

  def up
    RENAMED_TABLES.each do |old_name, new_name|
      rename_table(old_name, new_name) if table_exists?(old_name) && !table_exists?(new_name)
    end

    # rename_table only renames conventionally named indexes; sweep up the
    # custom-named ones, primary keys, and any readonly triggers/functions
    # left by the column-drop lifecycle.
    DB
      .query_single(
        "SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND indexname LIKE '%resenha%'",
      )
      .each { |index| execute "ALTER INDEX #{index} RENAME TO #{index.gsub("resenha", "voice")}" }

    DB
      .query(
        "SELECT t.tgname, c.relname FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid " \
          "WHERE NOT t.tgisinternal AND t.tgname LIKE '%resenha%'",
      )
      .each do |row|
        execute "ALTER TRIGGER #{row.tgname} ON #{row.relname} RENAME TO #{row.tgname.gsub("resenha", "voice")}"
      end

    DB
      .query_single(
        "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace " \
          "WHERE n.nspname = 'public' AND p.proname LIKE '%resenha%'",
      )
      .each do |function|
        execute "ALTER FUNCTION #{function}() RENAME TO #{function.gsub("resenha", "voice")}"
      end

    execute <<~SQL
      UPDATE site_settings
      SET name = REPLACE(name, 'resenha_', 'voice_')
      WHERE name LIKE 'resenha\\_%'
        AND REPLACE(name, 'resenha_', 'voice_') NOT IN (SELECT name FROM site_settings)
    SQL

    # The old default admitted the deprecated `everyone` pseudogroup (0);
    # anonymous_users + logged_in_users (4|5) is the equivalent going forward.
    execute <<~SQL
      UPDATE site_settings
      SET value = '4|5'
      WHERE name = 'voice_allowed_groups' AND value = '0'
    SQL

    execute <<~SQL
      UPDATE reviewables
      SET type = 'ReviewableVoiceUser'
      WHERE type = 'ReviewableResenhaUser'
    SQL

    execute <<~SQL if table_exists?(:chat_thread_custom_fields)
        UPDATE chat_thread_custom_fields
        SET name = 'voice_room_id'
        WHERE name = 'resenha_room_id'
      SQL

    execute <<~SQL
      UPDATE badge_groupings
      SET name = 'Voice'
      WHERE name = 'Resenha'
        AND NOT EXISTS (SELECT 1 FROM badge_groupings WHERE name = 'Voice')
    SQL

    # Cooked room hashtags and links embed the old /resenha mount point.
    execute <<~SQL
      UPDATE posts
      SET baked_version = NULL
      WHERE cooked LIKE '%/resenha/%'
    SQL

    execute <<~SQL if table_exists?(:chat_messages)
        UPDATE chat_messages
        SET cooked_version = NULL
        WHERE cooked LIKE '%/resenha/%'
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
