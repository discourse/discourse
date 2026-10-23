# frozen_string_literal: true

class CopyLivestreamSettingsToCalendar < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'livestream_embeddable_chat_allowed_paths', data_type, value, created_at, updated_at
      FROM site_settings
      WHERE name = 'discourse_livestream_embeddable_chat_allowed_paths'
      ON CONFLICT (name) DO NOTHING
    SQL

    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'livestream_enable_modal_chat_on_mobile', data_type, value, created_at, updated_at
      FROM site_settings
      WHERE name = 'discourse_livestream_enable_modal_chat_on_mobile'
      ON CONFLICT (name) DO NOTHING
    SQL

    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'livestream_chat_allowed_groups', data_type, value, created_at, updated_at
      FROM site_settings
      WHERE name = 'discourse_livestream_chat_allowed_groups'
      ON CONFLICT (name) DO NOTHING
    SQL

    livestream_plugin_enabled =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'discourse_livestream_enabled' AND value = 't'",
      )
    return if livestream_plugin_enabled.blank?

    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      SELECT 'livestream_enabled', 5, 't', NOW(), NOW()
      ON CONFLICT (name) DO NOTHING
    SQL

    execute <<~SQL
      UPDATE site_settings SET value = 'f' WHERE name = 'discourse_livestream_enabled'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
