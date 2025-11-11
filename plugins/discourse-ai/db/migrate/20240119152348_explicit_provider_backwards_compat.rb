# frozen_string_literal: true

class ExplicitProviderBackwardsCompat < ActiveRecord::Migration[7.0]
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

    providers = %w[aws_bedrock anthropic open_ai hugging_face vllm google]
    # Sanity check to make sure we won't add provider twice.
    return if providers.include?(setting_value.split(":").first)

    if !setting_value && feature_enabled
      # Enabled and using old default (gpt-3.5-turbo)
      DB.exec(
        "UPDATE site_settings SET value='open_ai:gpt-3.5-turbo' WHERE name=:llm_setting",
        llm_setting: llm_setting_name,
      )
    elsif setting_value && !feature_enabled
      # They'll have to choose an LLM model again before enabling the feature
      DB.exec("DELETE FROM site_settings WHERE name=:llm_setting", llm_setting: llm_setting_name)
    elsif setting_value && feature_enabled
      DB.exec(
        "UPDATE site_settings SET value=:new_value WHERE name=:llm_setting",
        llm_setting: llm_setting_name,
        new_value: append_provider(setting_value),
      )
    end
  end

  def append_provider(value)
    open_ai_models = %w[gpt-3.5-turbo gpt-4 gpt-3.5-turbo-16k gpt-4-32k gpt-4-turbo gpt-4o]
    return "open_ai:#{value}" if open_ai_models.include?(value)
    return "google:#{value}" if value == "gemini-pro"

    hf_models = %w[StableBeluga2 Upstage-Llama-2-*-instruct-v2 Llama2-*-chat-hf Llama2-chat-hf]
    return "hugging_face:#{value}" if hf_models.include?(value)

    # Models available through multiple providers
    claude_models = %w[claude-instant-1 claude-2]
    if claude_models.include?(value)
      has_bedrock_creds =
        DB.query_single(
          "SELECT value FROM site_settings WHERE name = 'ai_bedrock_secret_access_key' OR name = 'ai_bedrock_access_key_id' ",
        ).length > 0

      if has_bedrock_creds
        return "aws_bedrock:#{value}"
      else
        return "anthropic:#{value}"
      end
    end

    mixtral_models = %w[mistralai/Mixtral-8x7B-Instruct-v0.1 mistralai/Mistral-7B-Instruct-v0.2]
    if mixtral_models.include?(value)
      vllm_configured =
        DB.query_single(
          "SELECT value FROM site_settings WHERE name = 'ai_vllm_endpoint_srv' OR name = 'ai_vllm_endpoint' ",
        ).length > 0

      if vllm_configured
        "vllm:#{value}"
      else
        "hugging_face:#{value}"
      end
    end
  end
end
