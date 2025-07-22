# frozen_string_literal: true

class ChooseLlmModelSettingMigration < ActiveRecord::Migration[7.0]
  def up
    transition_to_llm_model("ai_helper_model")
    transition_to_llm_model("ai_embeddings_semantic_search_hyde_model")
  end

  def transition_to_llm_model(llm_setting_name)
    setting_value =
      DB
        .query_single(
          "SELECT value FROM site_settings WHERE name = :llm_setting",
          llm_setting: llm_setting_name,
        )
        .first
        .to_s

    return if setting_value.empty?

    provider_and_model = setting_value.split(":")
    provider = provider_and_model.first
    model = provider_and_model.second
    return if provider == "custom"

    llm_model_id = DB.query_single(<<~SQL, provider: provider, model: model).first.to_s
        SELECT id FROM llm_models WHERE provider = :provider AND name = :model
    SQL

    return if llm_model_id.empty?

    DB.exec(<<~SQL, llm_setting: llm_setting_name, new_value: "custom:#{llm_model_id}")
      UPDATE site_settings SET value=:new_value WHERE name=:llm_setting
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
