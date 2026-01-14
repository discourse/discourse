# frozen_string_literal: true

class LlmModelsForSummarization < ActiveRecord::Migration[7.0]
  def up
    setting_value =
      DB
        .query_single(
          "SELECT value FROM site_settings WHERE name = :llm_setting",
          llm_setting: "ai_summarization_strategy",
        )
        .first
        .to_s

    return if setting_value.empty?

    gpt_models = %w[gpt-4 gpt-4-32k gpt-4-turbo gpt-4o gpt-3.5-turbo gpt-3.5-turbo-16k]
    gemini_models = %w[gemini-pro gemini-1.5-pro gemini-1.5-flash]
    claude_models = %w[claude-2 claude-instant-1 claude-3-haiku claude-3-sonnet claude-3-opus]
    oss_models = %w[mistralai/Mixtral-8x7B-Instruct-v0.1 mistralai/Mixtral-8x7B-Instruct-v0.1]

    providers = []
    prov_priority = ""

    if gpt_models.include?(setting_value)
      providers = %w[azure open_ai]
      prov_priority = "azure"
    elsif gemini_models.include?(setting_value)
      providers = %w[google]
      prov_priority = "google"
    elsif claude_models.include?(setting_value)
      providers = %w[aws_bedrock anthropic]
      prov_priority = "aws_bedrock"
    elsif oss_models.include?(setting_value)
      providers = %w[hugging_face vllm]
      prov_priority = "vllm"
    end

    insert_llm_model(setting_value, providers, prov_priority) if providers.present?
  end

  def insert_llm_model(old_value, providers, priority)
    matching_models = DB.query(<<~SQL, model_name: old_value, providers: providers)
      SELECT * FROM llm_models WHERE name = :model_name AND provider IN (:providers)
    SQL

    return if matching_models.empty?

    priority_model = matching_models.find { |m| m.provider == priority } || matching_models.first
    new_value = "custom:#{priority_model.id}"

    DB.exec(<<~SQL, new_value: new_value)
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES ('ai_summarization_model', 1, :new_value, NOW(), NOW())
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
