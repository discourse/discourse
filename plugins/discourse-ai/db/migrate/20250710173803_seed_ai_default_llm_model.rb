# frozen_string_literal: true
class SeedAiDefaultLlmModel < ActiveRecord::Migration[7.2]
  def up
    return if DB.query_single("SELECT 1 FROM llm_models LIMIT 1").empty?

    last_model_id = DB.query_single("SELECT id FROM llm_models ORDER BY id DESC LIMIT 1").first

    if last_model_id.present?
      execute "UPDATE site_settings SET value = '#{last_model_id}' WHERE name = 'ai_default_llm_model' AND (value IS NULL OR value = '');"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
