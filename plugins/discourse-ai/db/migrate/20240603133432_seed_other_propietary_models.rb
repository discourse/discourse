# frozen_string_literal: true

class SeedOtherPropietaryModels < ActiveRecord::Migration[7.0]
  def up
    models = []

    gemini_key = fetch_setting("ai_gemini_api_key")
    enabled_models = fetch_setting("ai_bot_enabled_chat_bots")&.split("|").to_a

    if gemini_key.present?
      gemini_models = %w[gemini-pro gemini-1.5-pro gemini-1.5-flash]

      gemini_models.each do |gm|
        url = "https://generativelanguage.googleapis.com/v1beta/models/#{gemini_mapped_model(gm)}"

        bot_user_id = "NULL"
        bot_user_id = -115 if gm == "gemini-1.5-pro" && has_companion_user?(-115)

        enabled = enabled_models.include?(gm)
        models << "('#{gm.titleize}', '#{gm}', 'google', 'DiscourseAi::Tokenizer::OpenAiTokenizer', '#{gemini_tokens(gm)}', '#{url}', '#{gemini_key}', #{bot_user_id}, #{enabled}, NOW(), NOW())"
      end
    end

    cohere_key = fetch_setting("ai_cohere_api_key")

    if cohere_key.present?
      cohere_models = %w[command-light command command-r command-r-plus]

      cohere_models.each do |cm|
        bot_user_id = "NULL"
        bot_user_id = -120 if cm == "command-r-plus" && has_companion_user?(-120)

        enabled = enabled_models.include?(cm)
        models << "('#{cm.titleize}', '#{cm}', 'cohere', 'DiscourseAi::Tokenizer::OpenAiTokenizer', #{cohere_tokens(cm)}, 'https://api.cohere.ai/v1/chat', '#{cohere_key}', #{bot_user_id}, #{enabled}, NOW(), NOW())"
      end
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

  def cohere_tokens(model)
    case model
    when "command-light"
      4096
    when "command"
      8192
    when "command-r"
      131_072
    when "command-r-plus"
      131_072
    else
      8192
    end
  end

  def gemini_mapped_model(model)
    case model
    when "gemini-1.5-pro"
      "gemini-1.5-pro-latest"
    when "gemini-1.5-flash"
      "gemini-1.5-flash-latest"
    else
      "gemini-pro-latest"
    end
  end

  def gemini_tokens(model)
    if model.start_with?("gemini-1.5")
      # technically we support 1 million tokens, but we're being conservative
      800_000
    else
      16_384 # 50% of model tokens
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
