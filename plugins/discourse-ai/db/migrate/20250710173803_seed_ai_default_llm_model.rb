# frozen_string_literal: true
class SeedAiDefaultLlmModel < ActiveRecord::Migration[7.2]
  def up
    return if DB.query_single("SELECT 1 FROM llm_models LIMIT 1").empty?

    last_model_id = DB.query_single("SELECT id FROM llm_models ORDER BY id DESC LIMIT 1").first

    if last_model_id.present?
      DB.exec(<<~SQL, llm_setting: "ai_default_llm_model", default: "#{last_model_id}")
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES (:llm_setting, 1, :default, NOW(), NOW())
        ON CONFLICT (name)
        DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
