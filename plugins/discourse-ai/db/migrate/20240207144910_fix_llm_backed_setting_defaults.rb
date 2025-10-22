# frozen_string_literal: true

# Some sites defaults weren't migrated correctly due to the previous migration
# using the value as the if condition instead of checking with String#empty?
class FixLlmBackedSettingDefaults < ActiveRecord::Migration[7.0]
  def up
    backfill_settings("composer_ai_helper_enabled", "ai_helper_model")
    backfill_settings(
      "ai_embeddings_semantic_search_enabled",
      "ai_embeddings_semantic_search_hyde_model",
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def backfill_settings(feature_setting_name, llm_setting_name)
    feature_enabled =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = :setting_name",
        setting_name: feature_setting_name,
      ).first == "t"

    setting_value =
      DB
        .query_single(
          "SELECT value FROM site_settings WHERE name = :llm_setting",
          llm_setting: llm_setting_name,
        )
        .first
        .to_s
    using_old_default = setting_value.empty?

    providers = %w[aws_bedrock anthropic open_ai hugging_face vllm google]
    # Sanity check to make sure we won't add provider twice.
    return if providers.include?(setting_value.split(":").first)

    if using_old_default && feature_enabled
      # Enabled and using old default (gpt-3.5-turbo)
      DB.exec(<<~SQL, llm_setting: llm_setting_name, default: "open_ai:gpt-3.5-turbo")
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES (:llm_setting, 1, :default, NOW(), NOW())
      SQL
    end
  end
end
