# frozen_string_literal: true

class SeedOssModels < ActiveRecord::Migration[7.0]
  def up
    models = []
    enabled_models = fetch_setting("ai_bot_enabled_chat_bots")&.split("|").to_a
    enabled = enabled_models.include?("mixtral-8x7B-Instruct-V0.1")

    hf_key = fetch_setting("ai_hugging_face_api_key")
    hf_url = fetch_setting("ai_hugging_face_api_url")

    user_id = has_companion_user?(-114) ? -114 : "NULL"

    if hf_url.present? && hf_key.present?
      hf_token_limit = fetch_setting("ai_hugging_face_token_limit")
      hf_display_name = fetch_setting("ai_hugging_face_model_display_name")

      name = hf_display_name || "mistralai/Mixtral"
      token_limit = hf_token_limit || 32_000

      models << "('#{name}', '#{name}', 'hugging_face', 'DiscourseAi::Tokenizer::MixtralTokenizer', #{token_limit}, '#{hf_url}', '#{hf_key}', #{user_id}, #{enabled}, NOW(), NOW())"
    end

    vllm_key = fetch_setting("ai_vllm_api_key")
    vllm_url = fetch_setting("ai_vllm_endpoint")

    if vllm_key.present? && vllm_url.present?
      url = "#{vllm_url}/v1/chat/completions"
      name = "mistralai/Mixtral"

      models << "('#{name}', '#{name}', 'vllm', 'DiscourseAi::Tokenizer::MixtralTokenizer', 32000, '#{url}', '#{vllm_key}', #{user_id}, #{enabled}, NOW(), NOW())"
    end

    vllm_srv = fetch_setting("ai_vllm_endpoint_srv")
    srv_reserved_url = "https://vllm.shadowed-by-srv.invalid"

    srv_record =
      DB.query_single(
        "SELECT id FROM llm_models WHERE url = :reserved",
        reserved: srv_reserved_url,
      ).first

    if vllm_srv.present? && srv_record.nil?
      url = "https://vllm.shadowed-by-srv.invalid"
      name = "mistralai/Mixtral"

      models << "('vLLM SRV LLM', '#{name}', 'vllm', 'DiscourseAi::Tokenizer::MixtralTokenizer', 32000, '#{url}', '#{vllm_key}', #{user_id}, #{enabled}, NOW(), NOW())"
    end

    if models.present?
      rows = models.compact.join(", ")

      DB.exec(<<~SQL, rows: rows) if rows.present?
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

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
