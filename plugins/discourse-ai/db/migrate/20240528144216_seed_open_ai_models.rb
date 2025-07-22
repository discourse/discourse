# frozen_string_literal: true

class SeedOpenAiModels < ActiveRecord::Migration[7.0]
  def up
    models = []

    open_ai_api_key = fetch_setting("ai_openai_api_key")
    enabled_models = fetch_setting("ai_bot_enabled_chat_bots")&.split("|").to_a
    enabled_models = ["gpt-3.5-turbo-16k"] if enabled_models.empty?

    if open_ai_api_key.present?
      models << mirror_open_ai(
        "GPT-3.5-Turbo",
        "gpt-3.5-turbo",
        8192,
        "ai_openai_gpt35_url",
        open_ai_api_key,
        -111,
        enabled_models,
      )
      models << mirror_open_ai(
        "GPT-3.5-Turbo-16K",
        "gpt-3.5-turbo-16k",
        16_384,
        "ai_openai_gpt35_16k_url",
        open_ai_api_key,
        -111,
        enabled_models,
      )
      models << mirror_open_ai(
        "GPT-4",
        "gpt-4",
        8192,
        "ai_openai_gpt4_url",
        open_ai_api_key,
        -110,
        enabled_models,
      )
      models << mirror_open_ai(
        "GPT-4-32K",
        "gpt-4-32k",
        32_768,
        "ai_openai_gpt4_32k_url",
        open_ai_api_key,
        -110,
        enabled_models,
      )
      models << mirror_open_ai(
        "GPT-4-Turbo",
        "gpt-4-turbo",
        131_072,
        "ai_openai_gpt4_turbo_url",
        open_ai_api_key,
        -113,
        enabled_models,
      )
      models << mirror_open_ai(
        "GPT-4o",
        "gpt-4o",
        131_072,
        "ai_openai_gpt4o_url",
        open_ai_api_key,
        -121,
        enabled_models,
      )
    end

    if models.present?
      rows = models.compact.join(", ")

      DB.exec(<<~SQL) if rows.present?
        INSERT INTO llm_models(display_name, name, provider, tokenizer, max_prompt_tokens, url, api_key, user_id, enabled_chat_bot, created_at, updated_at)
        VALUES #{rows};
      SQL
    end
  end

  def has_companion_user?(user_id)
    DB.query_single("SELECT id FROM users WHERE id = :user_id", user_id: user_id).first.present?
  end

  def fetch_setting(name)
    DB.query_single(
      "SELECT value FROM site_settings WHERE name = :setting_name",
      setting_name: name,
    ).first
  end

  def mirror_open_ai(
    display_name,
    name,
    max_prompt_tokens,
    setting_name,
    key,
    bot_id,
    enabled_models
  )
    url = fetch_setting(setting_name) || "https://api.openai.com/v1/chat/completions"
    user_id = has_companion_user?(bot_id) ? bot_id : "NULL"
    enabled = enabled_models.include?(name)

    "('#{display_name}', '#{name}', 'open_ai', 'DiscourseAi::Tokenizer::OpenAiTokenizer', #{max_prompt_tokens}, '#{url}', '#{key}', #{user_id}, #{enabled}, NOW(), NOW())"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
