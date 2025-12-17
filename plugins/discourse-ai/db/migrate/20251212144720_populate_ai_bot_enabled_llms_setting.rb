# frozen_string_literal: true

class PopulateAiBotEnabledLlmsSetting < ActiveRecord::Migration[7.2]
  def up
    enabled_ids =
      DB.query_single("SELECT id FROM llm_models WHERE enabled_chat_bot = true ORDER BY id")

    return if enabled_ids.empty?

    setting_value = enabled_ids.join("|")

    DB.exec(<<~SQL, setting: "ai_bot_enabled_llms", value: setting_value)
      INSERT INTO site_settings (name, value, data_type, created_at, updated_at)
      VALUES (:setting, :value, 8, NOW(), NOW())
      ON CONFLICT (name) DO UPDATE SET value = :value, updated_at = NOW()
    SQL
  end

  def down
    DB.exec("DELETE FROM site_settings WHERE name = 'ai_bot_enabled_llms'")
  end
end
