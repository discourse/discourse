# frozen_string_literal: true
class EnableDiscoverFeatureIfConfigured < ActiveRecord::Migration[8.0]
  def up
    discover_persona_id = from_setting("ai_bot_discover_persona")
    ai_bot_enabled = from_setting("ai_bot_enabled")

    DB.exec(<<~SQL, value: true) if discover_persona_id && ai_bot_enabled
        UPDATE site_settings SET value = :value WHERE name = 'ai_discover_enabled'
      SQL

    # Copy Persona to new setting
    DB.exec(<<~SQL, value: discover_persona_id) if discover_persona_id
      UPDATE site_settings SET value = :value WHERE name = 'ai_discover_persona'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def from_setting(setting_name)
    DB.query_single(
      "SELECT value FROM site_settings WHERE name = :setting_name",
      setting_name: setting_name,
    )&.first
  end
end
