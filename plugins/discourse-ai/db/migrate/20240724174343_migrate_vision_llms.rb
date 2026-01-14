# frozen_string_literal: true
class MigrateVisionLlms < ActiveRecord::Migration[7.1]
  def up
    vision_models = %w[
      claude-3-sonnet
      claude-3-opus
      claude-3-haiku
      gpt-4-vision-preview
      gpt-4-turbo
      gpt-4o
      gemini-1.5-pro
      gemini-1.5-flash
    ]

    DB.exec(<<~SQL, names: vision_models)
      UPDATE llm_models
      SET vision_enabled = true
      WHERE name IN (:names)
    SQL

    current_value =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = :setting_name",
        setting_name: "ai_helper_image_caption_model",
      ).first

    if current_value && current_value != "llava"
      model_name = current_value.split(":").last
      llm_model =
        DB.query_single("SELECT id FROM llm_models WHERE name = :model", model: model_name).first

      if llm_model
        DB.exec(<<~SQL, new: "custom:#{llm_model}") if llm_model
          UPDATE site_settings
          SET value = :new
          WHERE name = 'ai_helper_image_caption_model'
        SQL
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
